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

  describe 'GET #show' do
    shared_examples 'a non existent account' do
      before do
        request.env['HTTP_REFERER'] = root_url # Needed for the redirect_to(root_url)
        get :show, params: { user: user }
      end

      it { expect(controller).to set_flash[:error].to("User not found #{user}") }
      it { expect(response).to redirect_to(root_url) }
    end

    context 'when the current user is admin' do
      before { login admin_user }

      it 'deleted users are shown' do
        get :show, params: { user: deleted_user }
        expect(response).to render_template('webui/users/show')
      end

      describe 'showing a non valid users' do
        subject(:user) { 'INVALID_USER' }

        it_behaves_like 'a non existent account'
      end
    end

    context "when the current user isn't admin" do
      before { login non_admin_user }

      describe 'showing a deleted user' do
        subject(:user) { deleted_user }

        it_behaves_like 'a non existent account'
      end

      describe 'showing an invalid user' do
        subject(:user) { 'INVALID_USER' }

        it_behaves_like 'a non existent account'
      end

      describe 'showing someone else' do
        it 'does not include requests' do
          get :show, params: { user: admin_user }
          expect(assigns(:reviews)).to be_nil
        end
      end
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
