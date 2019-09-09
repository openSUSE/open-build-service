require 'rails_helper'

RSpec.describe Webui::UsersController do
  let!(:user) { create(:confirmed_user, login: 'tom') }
  let!(:non_admin_user) { create(:confirmed_user, login: 'moi') }
  let!(:admin_user) { create(:admin_user, login: 'king') }
  let(:deleted_user) { create(:deleted_user) }
  let!(:non_admin_user_request) { create(:set_bugowner_request, priority: 'critical', creator: non_admin_user) }

  describe 'GET #index' do
    context 'as admin' do
      before do
        login admin_user
        get :index
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context 'as non-admin' do
      before do
        login non_admin_user
        get :index
      end

      it { expect(response).not_to(have_http_status(:ok)) }
    end
  end

  describe 'POST #create' do
    let!(:new_user) { build(:user, login: 'moi_new') }

    context 'when existing user is already registered with this login' do
      before do
        already_registered_user = create(:confirmed_user, login: 'previous_user')
        post :create, params: { login: already_registered_user.login,
                                email: already_registered_user.email, password: 'buildservice' }
      end

      it { expect(flash[:error]).not_to be(nil) }
      it { expect(response).to redirect_to root_path }
    end

    context 'when home project creation enabled' do
      before do
        allow(Configuration).to receive(:allow_user_to_create_home_project).and_return(true)
        post :create, params: { login: new_user.login, email: new_user.email,
                                password: 'buildservice' }
      end

      it { expect(flash[:success]).to eq("The account '#{new_user.login}' is now active.") }
      it { expect(response).to redirect_to project_show_path(new_user.home_project) }
    end

    context 'when home project creation disabled' do
      before do
        allow(Configuration).to receive(:allow_user_to_create_home_project).and_return(false)
        post :create, params: { login: new_user.login,
                                email: new_user.email, password: 'buildservice' }
      end

      it { expect(flash[:success]).to eq("The account '#{new_user.login}' is now active.") }
      it { expect(response).to redirect_to root_path }
    end
  end
end
