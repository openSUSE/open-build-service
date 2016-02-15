require 'rails_helper'

RSpec.describe Webui::UserController do
  let!(:user) { create(:confirmed_user, login: "tom") }
  let!(:non_admin_user) { create(:confirmed_user, login: "moi") }
  let!(:admin_user) { create(:admin_user, login: "king") }
  let(:deleted_user) { create(:deleted_user) }

  describe "GET #index" do
    context "when the current user is admin" do
      before do
        login admin_user
        get :index
      end

      it { is_expected.to render_template("webui/user/index") }
    end

    context "when the current user isn't admin" do
      before do
        login non_admin_user
        get :index
      end

      it { expect(controller).to set_flash[:error].to('Requires admin privileges') }
      it { expect(response).to redirect_to root_path }
    end

    context "when the current user is nobody" do
      before do
        logout
        get :index
      end

      it { expect(controller).to set_flash[:error].to('Please login to access the requested page.') }
      it { expect(response).to redirect_to user_login_path }
    end
  end

  describe "GET #show" do
    shared_examples "a non existent account" do
      before do
        request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
        get :show, {user: user}
      end

      it { expect(controller).to set_flash[:error].to("User not found #{user}") }
      it { expect(response).to redirect_to :back }
    end

    context "when the current user is admin" do
      before { login admin_user }

      it "deleted users are shown" do
        get :show, { user: deleted_user }
        expect(response).to render_template("webui/user/show")
      end

      describe "showing a non valid users" do
        subject(:user) { 'INVALID_USER' }
        it_should_behave_like "a non existent account"
      end
    end

    context "when the current user isn't admin" do
      before { login non_admin_user }

      describe "showing a deleted user" do
        subject(:user) { deleted_user }
        it_should_behave_like "a non existent account"
      end

      describe "showing a non valid users" do
        subject(:user) { 'INVALID_USER' }
        it_should_behave_like "a non existent account"
      end
    end
  end

  describe "GET #user_edit" do
    context "when the current user is admin" do
      before do
        login admin_user
        get :edit, {user: user}
      end

      it { is_expected.to render_template("webui/user/edit") }
    end

    context "when the current user isn't admin" do
      before do
        login non_admin_user
        get :edit, {user: user}
      end

      it { expect(controller).to set_flash[:error].to('Requires admin privileges') }
      it { expect(response).to redirect_to root_path }
    end
  end

  describe "GET #home" do
    skip
  end

  describe "GET #requests" do
    skip
  end

  describe "GET #save" do
=begin
    SAVE from edit

        expect(page).to have_text("Editing User Data for User")
        fill_in 'realname', with: Faker::Name.name
        fill_in 'email', with: Faker::Internet.email
        click_button 'Update'

        expect(page).to have_content("User data for user '#{user.login}' successfully updated.")
=end
    skip
  end

  describe "GET #delete" do
    skip
  end

  describe "GET #confirm" do
    skip
  end

  describe "GET #lock" do
    skip
  end

  describe "GET #admin" do
    skip
  end

  describe "GET #save_dialog" do
    skip
  end

  describe "GET #user_icon" do
    skip
  end

  describe "GET #icon" do
    skip
  end

  describe "GET #register" do
    skip
  end

  describe "GET #register_user" do
    skip
  end

  describe "GET #password_dialog" do
    skip
  end

  describe "GET #change_password" do
    skip
  end

  describe "GET #autocomplete" do
    skip
  end

  describe "GET #tokens" do
    skip
  end

  describe "GET #notifications" do
    skip
  end

  describe "GET #update_notifications" do
    skip
  end

  describe "GET #list_users(prefix = nil, hash = nil)" do
    skip
  end
end
