require 'rails_helper'

RSpec.describe Webui::UserController do
  let!(:user) { create(:confirmed_user, login: "tom") }
  let!(:non_admin_user) { create(:confirmed_user, login: "moi") }
  let!(:admin_user) { create(:admin_user, login: "king") }
  let(:deleted_user) { create(:deleted_user) }
  let!(:non_admin_user_request) { create(:bs_request, creator: non_admin_user, commenter: non_admin_user) }

  it { is_expected.to use_before_action(:require_login) }
  it { is_expected.to use_before_action(:require_admin) }

  describe "GET #index" do
    before do
      login admin_user
      get :index
    end

    it { is_expected.to render_template("webui/user/index") }
  end

  describe "GET #show" do
    shared_examples "a non existent account" do
      before do
        request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to(root_url)
        get :show, params: { user: user }
      end

      it { expect(controller).to set_flash[:error].to("User not found #{user}") }
      it { expect(response).to redirect_to(root_url) }
    end

    context "when the current user is admin" do
      before { login admin_user }

      it "deleted users are shown" do
        get :show, params: { user: deleted_user }
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
      describe "showing an invalid user" do
        subject(:user) { 'INVALID_USER' }
        it_should_behave_like "a non existent account"
      end
      describe "showing someone else" do
        it 'does not include requests' do
          get :show, params: { user: admin_user }
          expect(assigns(:reviews)).to be_nil
        end
      end
    end
  end

  describe "GET #user_edit" do
    before do
      login admin_user
      get :edit, params: { user: user }
    end

    it { is_expected.to render_template("webui/user/edit") }
  end

  describe "POST #do_login" do
    before do
      request.env["HTTP_REFERER"] = search_url # Needed for the redirect_to(root_url)
    end

    it 'logs in users with correct credentials' do
      post :do_login, params: { username: user.login, password: 'buildservice' }
      expect(response).to redirect_to search_url
    end

    it 'tells users about wrong credentials' do
      post :do_login, params: { username: user.login, password: 'password123' }
      expect(response).to redirect_to user_login_path
      expect(flash[:error]).to eq("Authentication failed")
    end

    it 'tells users about wrong state' do
      user.update_attribute('state', :locked)
      post :do_login, params: { username: user.login, password: 'buildservice' }
      expect(response).to redirect_to root_path
      expect(flash[:error]).to eq("Your account is disabled. Please contact the adminsitrator for details.")
    end

    it 'assigns the current user' do
      post :do_login, params: { username: user.login, password: 'buildservice' }
      expect(User.current).to eq(user)
      expect(session[:login]).to eq(user.login)
    end
  end

  describe "GET #home" do
    skip
  end

  describe "GET #requests" do
    before { login non_admin_user }

    it 'renders the requests as json' do
      get :requests, { format: :json }
      expect(response.body).to eq({ draw: 1, recordsTotal: 1, recordsFiltered: 1, data: [] }.to_json)
    end
  end

  describe "POST #save" do
    context "when user is updating its own profile" do
      context "with valid data" do
        before do
          login user
          post :save, params: { user: user, realname: 'another real name', email: 'new_valid@email.es' }
          user.reload
        end

        it { expect(flash[:success]).to eq("User data for user '#{user.login}' successfully updated.") }
        it { expect(user.realname).to eq('another real name') }
        it { expect(user.email).to eq('new_valid@email.es') }
        it { is_expected.to redirect_to user_show_path(user) }
      end

      context "with invalid data" do
        before do
          login user
          post :save, params: { user: user, realname: "another real name", email: "" }
          user.reload
        end

        it { expect(flash[:error]).to eq("Couldn't update user: Validation failed: Email must be given, Email must be a valid email address..") }
        it { expect(user.realname).to eq(user.realname) }
        it { expect(user.email).to eq(user.email) }
        it { is_expected.to redirect_to user_show_path(user) }
      end
    end

    context "when user is trying to update another user's profile" do
      before do
        login user
        request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to(root_url)
        post :save, params: { user: non_admin_user, realname: 'another real name', email: 'new_valid@email.es' }
        non_admin_user.reload
      end

      it { expect(non_admin_user.realname).not_to eq('another real name') }
      it { expect(non_admin_user.email).not_to eq('new_valid@email.es') }
      it { expect(flash[:error]).to eq("Can't edit #{non_admin_user.login}") }
      it { is_expected.to redirect_to(root_url) }
    end

    context "when admin is updating another user's profile" do
      before do
        login admin_user
        post :save, params: { user: user, realname: 'another real name', email: 'new_valid@email.es' }
        user.reload
      end

      it { expect(user.realname).to eq('another real name') }
      it { expect(user.email).to eq('new_valid@email.es') }
      it { is_expected.to redirect_to user_show_path(user) }
    end
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

  describe "POST #register" do
    let!(:new_user) { build(:user, login: 'moi_new') }

    context "when existing user is already registered with this login" do
      before do
        already_registered_user = create(:confirmed_user, login: 'previous_user')
        post :register, params: { login: already_registered_user.login, email: already_registered_user.email, password: 'buildservice' }
      end

      it { expect(flash[:error]).not_to be nil }
      it { expect(response).to redirect_to root_path }
    end

    context "when home project creation enabled" do
      before do
        allow(Configuration).to receive(:allow_user_to_create_home_project).and_return(true)
        post :register, params: { login: new_user.login, email: new_user.email, password: 'buildservice' }
      end

      it { expect(flash[:success]).to eq("The account '#{new_user.login}' is now active.") }
      it { expect(response).to redirect_to project_show_path(new_user.home_project) }
    end

    context "when home project creation disabled" do
      before do
        allow(Configuration).to receive(:allow_user_to_create_home_project).and_return(false)
        post :register, params: { login: new_user.login, email: new_user.email, password: 'buildservice' }
      end

      it { expect(flash[:success]).to eq("The account '#{new_user.login}' is now active.") }
      it { expect(response).to redirect_to root_path }
    end
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
