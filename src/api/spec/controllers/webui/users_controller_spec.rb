RSpec.describe Webui::UsersController do
  let!(:user) { create(:confirmed_user, login: 'tom') }
  let!(:non_admin_user) { create(:confirmed_user, login: 'moi') }
  let!(:admin_user) { create(:admin_user, login: 'king') }
  let(:deleted_user) { create(:deleted_user) }
  let!(:non_admin_user_request) { create(:set_bugowner_request, priority: 'critical', creator: non_admin_user) }

  describe 'GET #index' do
    it { is_expected.to use_after_action(:verify_authorized) }

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

  describe 'GET #edit' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'for logged in user' do
      before do
        login admin_user
        get :edit, params: { login: user.login }
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end

  describe 'GET #edit_account' do
    it { is_expected.to use_after_action(:verify_authorized) }
  end

  describe 'GET #show' do
    shared_examples 'a non existent account' do
      before do
        request.env['HTTP_REFERER'] = root_url # Needed for the redirect_to(root_url)
        get :show, params: { login: user }
      end

      it { expect(controller).to set_flash[:error].to("User not found #{user}") }
      it { expect(response).to redirect_to(root_url) }
    end

    context 'when the current user is admin' do
      before { login admin_user }

      it 'deleted users are shown' do
        get :show, params: { login: deleted_user.login }
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
          get :show, params: { login: admin_user.login }
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

      it { expect(flash[:error]).not_to be_nil }
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

  describe 'DELETE #destroy' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'called by an admin user' do
      before do
        login(admin_user)
      end

      it "changes the state to 'deleted'" do
        delete :destroy, params: { login: user.login }
        expect(user.reload.state).to eq('deleted')
        expect(user.reload.email).to eq('')
        expect(user.reload.realname).to eq('')
      end
    end

    context 'called by a user that is not admin' do
      let(:non_admin_user) { create(:confirmed_user) }

      before do
        login(non_admin_user)
      end

      it "does not change the state to 'deleted'" do
        delete :destroy, params: { login: user.login }
        expect(user.reload.state).to eq('confirmed')
      end
    end
  end

  describe 'POST #update' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'when user is updating its own profile' do
      context 'with valid data' do
        before do
          login user
          post :update, params: { user: { login: user.login, realname: 'another real name', email: 'new_valid@email.es', state: 'locked',
                                          ignore_auth_services: true }, login: user.login }
          user.reload
        end

        it { expect(flash[:success]).to eq("User data for user '#{user.login}' successfully updated.") }
        it { expect(user.realname).to eq('another real name') }
        it { expect(user.email).to eq('new_valid@email.es') }
        it { expect(user.state).to eq('confirmed') }
        it { expect(user.ignore_auth_services).to be(false) }
        it { is_expected.to redirect_to user_path(user) }
      end

      context 'with invalid data' do
        before do
          login user
          post :update, params: { user: { login: user.login, realname: 'another real name', email: 'invalid' }, login: user.login }
          user.reload
        end

        it { expect(flash[:error]).to eq("Couldn't update user: Email must be a valid email address.") }
        it { expect(user.realname).not_to eq('another real name') }
        it { expect(user.email).not_to eq('invalid') }
        it { expect(user.state).to eq('confirmed') }
        it { is_expected.to redirect_to user_path(user) }
      end
    end

    context "when user is trying to update another user's profile" do
      before do
        login user
        post :update, params: { user: { login: non_admin_user.login, realname: 'another real name', email: 'new_valid@email.es' }, login: non_admin_user.login }
        non_admin_user.reload
      end

      it { expect(non_admin_user.realname).not_to eq('another real name') }
      it { expect(non_admin_user.email).not_to eq('new_valid@email.es') }
      it { expect(flash[:error]).to eq('Sorry, you are not authorized to update this user.') }
      it { is_expected.to redirect_to(root_url) }
    end

    context 'when user is trying to do some privilege escalation to another user' do
      before do
        login user
        post :update, params: { user: { login: non_admin_user.login, realname: 'hacked', email: 'hacked@example.org' }, login: user.login }
        non_admin_user.reload
      end

      it { expect(non_admin_user.realname).not_to eq('hacked') }
      it { expect(non_admin_user.email).not_to eq('hacked@example.org') }
    end

    context "when admin is updating another user's profile" do
      let(:old_global_role)  { create(:role, global: true, title: 'old_global_role') }
      let(:new_global_roles) { create_list(:role, 2, global: true) }
      let(:local_roles)      { create_list(:role, 2) }

      before do
        user.roles << old_global_role
        user.roles << local_roles

        login admin_user
        post :update, params: {
          user: {
            login: user.login,
            realname: 'another real name',
            email: 'new_valid@email.es',
            state: 'locked',
            role_ids: new_global_roles.pluck(:id),
            ignore_auth_services: 'true'
          },
          login: user.login
        }
        user.reload
      end

      it { expect(user.realname).to eq('another real name') }
      it { expect(user.email).to eq('new_valid@email.es') }
      it { expect(user.state).to eq('locked') }
      it { expect(user.ignore_auth_services).to be(true) }
      it { is_expected.to redirect_to user_path(user) }

      it "updates the user's roles" do
        expect(user.roles).not_to include(old_global_role)
        expect(user.roles).to include(*new_global_roles)
      end

      it 'does not remove non global roles' do
        expect(user.roles).to include(*local_roles)
      end
    end

    context 'admin activate a deleted user back' do
      before  do
        login admin_user
        post :update, params: {
          login: deleted_user.login,
          user: {
            login: deleted_user.login,
            state: 'confirmed'
          }
        }
        deleted_user.reload
      end

      it { expect(controller).to set_flash[:success] }
      it { expect(deleted_user.state).to eq('confirmed') }
    end

    context 'when roles parameter is empty' do
      let(:old_global_role) { create(:role, global: true, title: 'old_global_role') }
      let(:local_roles)     { create_list(:role, 2) }

      before do
        user.roles << old_global_role
        user.roles << local_roles

        login admin_user
        # Rails form helper sends an empty string in an array if no checkbox was marked
        post :update, params: { user: { login: user.login, email: 'new_valid@email.es', role_ids: [''] }, login: user.login }
        user.reload
      end

      it 'drops all global roles' do
        expect(user.roles).to match_array local_roles
      end
    end

    context 'when state and roles are not passed as parameter' do
      let(:old_global_role) { create(:role, global: true, title: 'old_global_role') }

      before do
        user.roles << old_global_role

        login admin_user
        post :update, params: { user: { login: user.login, email: 'new_valid@email.es' }, login: user.login }
        user.reload
      end

      it 'keeps the old state' do
        expect(user.state).to eq('confirmed')
      end

      it 'does not drop the roles' do
        expect(user.roles).to match_array old_global_role
      end
    end

    context 'for a moderator' do
      let(:moderator) { create(:moderator) }

      before do
        login(moderator)
      end

      context 'censor the user so they can not comment' do
        before do
          put :censor, params: { login: user.login, user: { censored: 'true' } }
        end

        it { expect(user.reload.censored).to be(true) }
        it { expect(flash[:success]).to eq("User '#{user.login}' successfully censored, they can't comment.") }
      end

      context 'passing parameters other than censored' do
        before do
          post :update, params: { login: user.login, user: { email: 'foo@bar.baz' } }
        end

        it "doesn't allow to update the user" do
          expect(user.reload.email).not_to eq('foo@bar.baz')
          expect(flash[:error]).to eq('Sorry, you are not authorized to update this user.')
        end
      end
    end
  end

  describe 'GET #autocomplete' do
    let!(:user) { create(:user, login: 'foobar') }

    it 'returns user login' do
      get :autocomplete, params: { term: 'foo', format: :json }
      expect(response.parsed_body).to contain_exactly('foobar')
    end
  end

  describe 'GET #tokens' do
    let!(:user) { create(:user, login: 'foobaz') }

    it 'returns user token as array of hash' do
      get :tokens, params: { q: 'foo', format: :json }
      expect(response.parsed_body).to contain_exactly({ 'name' => 'foobaz' })
    end
  end

  describe 'POST #change_password' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'authenticated' do
      before do
        login non_admin_user
        post :change_password, params: { login: non_admin_user, password: 'buildservice',
                                         new_password: 'opensuse', repeat_password: 'opensuse' }
      end

      it 'changes the password' do
        expect(controller).to set_flash[:success]
        expect(flash[:success]).to eq('Your password has been changed successfully.')
      end
    end

    context 'unauthenticated' do
      before do
        post :change_password, params: { login: non_admin_user, password: 'buildservice',
                                         new_password: 'opensuse', repeat_password: 'opensuse' }
      end

      it 'shows an error message' do
        expect(controller).to set_flash[:error]
        expect(flash[:error]).to eq('Please login to access the resource')
      end
    end
  end
end
