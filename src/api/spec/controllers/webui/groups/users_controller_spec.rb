require 'rails_helper'

RSpec.describe Webui::Groups::UsersController do
  let(:group) { create(:group) }
  let(:user) { create(:confirmed_user) }
  let(:admin) { create(:admin_user) }

  RSpec.shared_examples 'response for non existing user or group' do
    it 'reports an error' do
      expect(response).to have_http_status(:not_found)
      expect(flash[:error]).not_to be_nil
    end
  end

  describe 'POST create' do
    before do
      login(admin)
    end

    context 'when the user exists' do
      subject! do
        post :create, params: { group_title: group.title, user_login: user.login }, format: :js
      end

      it 'adds the user to the group' do
        expect(response).to redirect_to(group_show_path(title: group.title))
        expect(flash[:success]).not_to be_nil
        expect(group.users.where(groups_users: { user: user })).to exist
      end
    end

    context 'when the user does not exist' do
      subject! do
        post :create, params: { group_title: group.title, user_login: 'unknown_user' }, format: :js
      end

      include_examples 'response for non existing user or group'
      it { expect(group.users.where(groups_users: { user: user })).not_to exist }
    end

    context 'when the group does not exist' do
      subject! do
        post :create, params: { group_title: 'unknown_group', user_login: user.login }, format: :js
      end

      include_examples 'response for non existing user or group'
    end

    context 'when there is an error during user creation' do
      let!(:group_user) { create(:groups_user, group: group, user: user) }

      subject! do
        post :create, params: { group_title: group.title, user_login: user.login }, format: :js
      end

      it 'reports the error' do
        expect(response).to have_http_status(:bad_request)
        expect(flash[:error]).not_to be_nil
      end
    end
  end

  describe 'DELETE #destroy' do
    before do
      login(admin)
    end

    context 'when the user is not a group member' do
      subject! do
        delete :destroy, params: { group_title: group.title, user_login: user.login }, format: :js
      end

      it 'responds with an error message' do
        expect(flash[:error]).not_to be_nil
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the user is a member of the group' do
      let!(:groups_user) { create(:groups_user, user: user, group: group) }

      subject! do
        delete :destroy, params: { group_title: group.title, user_login: user.login }, format: :js
      end

      it 'removes the user from the group' do
        expect(response).to have_http_status(:success)
        expect(flash[:success]).not_to be_nil
        expect(group.users.where(groups_users: { user: user })).not_to exist
      end
    end

    context 'when the user does not exist' do
      subject! do
        delete :destroy, params: { group_title: group.title, user_login: 'unknown_user' }, format: :js
      end

      include_examples 'response for non existing user or group'
      it { expect(group.users.where(groups_users: { user: user })).not_to exist }
    end

    context 'when the group does not exist' do
      subject! do
        delete :destroy, params: { group_title: 'unknown_group', user_login: user.login }, format: :js
      end

      include_examples 'response for non existing user or group'
    end
  end

  describe 'POST #update' do
    before do
      login(admin)
    end

    context 'when the user is not a group member' do
      let(:group_maintainer) { create(:group_maintainer, group: group) }

      subject! do
        post :update, params: { group_title: group.title, user_login: user.login, maintainer: 'false' }, format: :js
      end

      it { is_expected.to have_http_status(:not_found) }
    end

    context 'when the user is a member of the group' do
      let!(:groups_user) { create(:groups_user, user: user, group: group) }

      context 'removing maintainer rights of a user' do
        let(:group_maintainer) { create(:group_maintainer, group: group) }

        subject! do
          post :update, params: { group_title: group.title, user_login: user.login, maintainer: 'false' }, format: :js
        end

        it 'removes maintainer rights from the group' do
          expect(response).to have_http_status(:success)
          expect(flash[:success]).not_to be_nil
          expect(group.maintainer?(user)).to be false
        end
      end

      context 'as a maintainer of the group' do
        subject! do
          post :update, params: { group_title: group.title, user_login: user.login, maintainer: 'true' }, format: :js
        end

        it 'gives maintainer rights to the user' do
          expect(response).to have_http_status(:success)
          expect(flash[:success]).not_to be_nil
          expect(group.maintainer?(user)).to be true
        end
      end
    end

    context 'when the user does not exist' do
      subject! do
        post :update, params: { group_title: group.title, user_login: 'unknown_user', maintainer: 'true' }, format: :js
      end

      include_examples 'response for non existing user or group'
      it { expect(group.users.where(groups_users: { user: user })).not_to exist }
    end

    context 'when the group does not exist' do
      subject! do
        post :update, params: { group_title: 'unknown_group', user_login: user.login, maintainer: 'true' }, format: :js
      end

      include_examples 'response for non existing user or group'
    end
  end
end
