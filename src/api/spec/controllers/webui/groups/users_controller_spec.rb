RSpec.describe Webui::Groups::UsersController do
  let(:group) { create(:group) }
  let(:user) { create(:confirmed_user) }
  let(:admin) { create(:admin_user) }

  describe 'POST create' do
    before do
      login(admin)
    end

    context 'when the user exists' do
      before do
        post :create, params: { group_title: group.title, user_login: user.login }
      end

      it 'adds the user to the group' do
        expect(response).to redirect_to(group_path(title: group.title))
        expect(flash[:success]).to eq("Added user '#{user}' to group '#{group}'")
        expect(group.users.where(groups_users: { user_id: user })).to exist
      end
    end

    context 'when the user does not exist' do
      before do
        post :create, params: { group_title: group.title, user_login: 'unknown_user' }
      end

      it { expect(flash[:error]).to eq("User 'unknown_user' not found") }
      it { expect(group.users.where(groups_users: { user_id: user })).not_to exist }
    end

    context 'when the group does not exist' do
      before do
        post :create, params: { group_title: 'unknown_group', user_login: user.login }
      end

      it { expect(flash[:error]).to eq("Group 'unknown_group' not found") }
    end

    context 'when there is an error during user creation' do
      let!(:group_user) { create(:groups_user, group: group, user: user) }

      before do
        post :create, params: { group_title: group.title, user_login: user.login }
      end

      it 'reports the error' do
        expect(flash[:error]).to eq("Couldn't add user '#{user}' to group '#{group}': User User already has this group")
      end
    end
  end

  describe 'DELETE #destroy' do
    before do
      login(admin)
    end

    context 'when the user is not a group member' do
      before do
        delete :destroy, params: { group_title: group.title, user_login: user.login }, format: :js
      end

      it 'responds with an error message' do
        expect(flash[:error]).to eq("User '#{user}' not found in group '#{group}'")
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the user is a member of the group' do
      let!(:groups_user) { create(:groups_user, user: user, group: group) }

      before do
        delete :destroy, params: { group_title: group.title, user_login: user.login }, format: :js
      end

      it 'removes the user from the group' do
        expect(response).to redirect_to(group_path(title: group.title))
        expect(flash[:success]).to eq("Removed user '#{user}' from group '#{group}'")
        expect(group.users.where(groups_users: { user_id: user })).not_to exist
      end
    end

    context 'when the user does not exist' do
      before do
        delete :destroy, params: { group_title: group.title, user_login: 'unknown_user' }, format: :js
      end

      it { expect(response).to have_http_status(:not_found) }
      it { expect(flash[:error]).to eq("User 'unknown_user' not found in group '#{group}'") }
      it { expect(group.users.where(groups_users: { user_id: user })).not_to exist }
    end

    context 'when the group does not exist' do
      before do
        delete :destroy, params: { group_title: 'unknown_group', user_login: user.login }, format: :js
      end

      it { expect(response).to have_http_status(:not_found) }
      it { expect(flash[:error]).to eq("Group 'unknown_group' not found") }
    end
  end

  describe 'POST #update' do
    before do
      login(admin)
    end

    context 'when the user is not a group member' do
      let(:group_maintainer) { create(:group_maintainer, group: group) }

      before do
        post :update, params: { group_title: group.title, user_login: user.login, maintainer: 'false' }, format: :js
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'when the user is a member of the group' do
      let!(:groups_user) { create(:groups_user, user: user, group: group) }

      context 'removing maintainer rights of a user' do
        let(:group_maintainer) { create(:group_maintainer, group: group) }

        before do
          post :update, params: { group_title: group.title, user_login: user.login, maintainer: 'false' }, format: :js
        end

        it 'removes maintainer rights from the group' do
          expect(response).to have_http_status(:success)
          expect(flash[:success]).to eq("Removed maintainer rights from '#{user}'")
          expect(group.maintainer?(user)).to be false
        end
      end

      context 'as a maintainer of the group' do
        before do
          post :update, params: { group_title: group.title, user_login: user.login, maintainer: 'true' }, format: :js
        end

        it 'gives maintainer rights to the user' do
          expect(response).to have_http_status(:success)
          expect(flash[:success]).to eq("Gave maintainer rights to '#{user}'")
          expect(group.maintainer?(user)).to be true
        end
      end
    end

    context 'when the user does not exist' do
      before do
        post :update, params: { group_title: group.title, user_login: 'unknown_user', maintainer: 'true' }, format: :js
      end

      it { expect(response).to have_http_status(:not_found) }
      it { expect(flash[:error]).to eq("User 'unknown_user' not found in group '#{group}'") }
      it { expect(group.users.where(groups_users: { user_id: user })).not_to exist }
    end

    context 'when the group does not exist' do
      before do
        post :update, params: { group_title: 'unknown_group', user_login: user.login, maintainer: 'true' }, format: :js
      end

      it { expect(response).to have_http_status(:not_found) }
      it { expect(flash[:error]).to eq("Group 'unknown_group' not found") }
    end
  end
end
