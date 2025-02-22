# frozen_string_literal: true

require "spec_helper"

module Decidim
  describe Decidim::Devise::RegistrationsController, type: :controller do
    routes { Decidim::Core::Engine.routes }

    let(:scope) { create(:scope, organization: organization) }
    let(:organization) { create(:organization) }
    let(:email) { "test@example.org" }

    let!(:city_parent_scope) do
      create(:scope,
             name: {
               fr: "Ville de Toulouse",
               en: "Toulouse city"
             },
             organization: organization)
    end
    let!(:metropolis_parent_scope) do
      create(:scope,
             name: {
               fr: "Métropole de Toulouse",
               en: "Toulouse metropolis"
             },
             organization: organization)
    end

    let!(:city_residential_area) { create(:scope, parent: city_parent_scope) }
    let!(:city_work_area) { create(:scope, parent: city_parent_scope) }

    before do
      request.env["devise.mapping"] = ::Devise.mappings[:user]
      request.env["decidim.current_organization"] = organization
    end

    describe "POST create" do
      let(:params) do
        {
          user: {
            sign_up_as: "user",
            name: "User",
            nickname: "nickname",
            email: email,
            password: "rPYWYKQJrXm97b4ytswc",
            password_confirmation: "rPYWYKQJrXm97b4ytswc",
            tos_agreement: "1",
            additional_tos: "1",
            living_area: "city",
            city_residential_area: city_residential_area.id.to_s,
            city_work_area: city_work_area.id.to_s,
            gender: "other",
            month: "January",
            year: "1992",
            underage: "1",
            statutory_representative_email: "statutory_representative_email@example.org"
          }
        }
      end

      def send_form_and_expect_rendering_the_new_template_again
        post :create, params: params
        expect(controller).to render_template "new"
      end

      context "when the user created is active for authentication" do
        before do
          expect_any_instance_of(Decidim::User) # rubocop:disable RSpec/AnyInstance
            .to receive(:active_for_authentication?)
            .at_least(:once)
            .and_return(true)
          expect(controller).to receive(:sign_up).and_call_original
        end

        it "doesn't ask the user to confirm the email" do
          post :create, params: params
          expect(controller.flash.notice).not_to have_content("confirmation")
        end
      end

      context "when the form is invalid" do
        let(:email) { nil }

        it "renders the new template" do
          send_form_and_expect_rendering_the_new_template_again
        end
      end

      context "when the registering user has pending invitations" do
        let(:user) { create(:user, organization: organization, email: email) }

        before do
          user.invite!
        end

        it "informs the user she must accept the pending invitation" do
          send_form_and_expect_rendering_the_new_template_again
          expect(controller.flash.now[:alert]).to have_content("You have a pending invitation, accept it to finish creating your account")
        end
      end
    end
  end
end
