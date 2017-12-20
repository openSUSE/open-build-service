require 'rails_helper'

RSpec.describe Webui::GroupsController do
  let(:group) { create(:group) }
  let(:another_group) { create(:group, title: "#{group.title}-#{SecureRandom.hex}") }
  let(:user) { create(:user) }

  # except [:show, :tokens, :autocomplete]
  it { is_expected.to use_before_action(:require_login) }
  # only: [:show, :update, :edit]
  it { is_expected.to use_before_action(:set_group) }
  # except: [:show, :autocomplete, :tokens]
  it { is_expected.to use_after_action(:verify_authorized) }

  describe 'GET show' do
    it 'is successful as nobody' do
      get :show, params: { title: group.title }
      expect(response).to have_http_status(:success)
    end

    it 'assigns @group' do
      get :show, params: { title: group.title }
      expect(assigns(:group)).to eq(group)
    end

    it 'redirects to root_path if group does not exist' do
      get :show, params: { title: 'Foobar' }
      expect(flash[:error]).to eq("Group 'Foobar' does not exist")
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'GET tokens' do
    it 'returns a hash with one group for a match' do
      get :tokens, params: { q: group.title }
      expect(response.body).to eq([{ name: group.title }].to_json)
    end

    it 'returns a hash with more than one group for a match' do
      another_group # necessary for initialization
      get :tokens, params: { q: group.title }
      expect(response.body).to eq([{ name: group.title }, { name: another_group.title }].to_json)
    end

    it 'returns empty hash if no match' do
      get :tokens, params: { q: 'no_group' }
      expect(response.body).to eq([].to_json)
    end
  end

  describe 'GET autocomplete' do
    it 'returns list with one group for a match' do
      get :autocomplete, params: { term: group.title }
      expect(response.body).to eq([group.title].to_json)
    end

    it 'returns list with more than one group for a match' do
      another_group # necessary for initialization
      get :autocomplete, params: { term: group.title }
      expect(response.body).to eq([group.title, another_group.title].to_json)
    end

    it 'returns empty list if no match' do
      get :autocomplete, params: { term: 'no_group' }
      expect(response.body).to eq([].to_json)
    end
  end

  describe 'GET edit' do
    let(:users_of_group) { create_list(:user, 3) }

    before do
      group.users << users_of_group

      login(user)
    end

    context 'as a normal user' do
      it 'does not allow to see the edit form used for updating a group' do
        get :edit, params: { title: group.title }

        expect(flash[:error]).to eq('Sorry, you are not authorized to update this Group.')
      end
    end

    context 'as a group maintainer' do
      before do
        create(:group_maintainer, user: user, group: group)
      end

      it 'shows edit form and populates it with data' do
        get :edit, params: { title: group.title }

        expect(response).to have_http_status(:success)
        assigned_members = assigns(:members).map { |user| user['name'] }
        expect(assigned_members).to match_array(users_of_group.map(&:login))
      end
    end
  end

  describe 'POST create' do
    let(:users_to_add) { create_list(:user, 3) }

    before do
      group.users << create(:user, login: 'existing_group_user')

      login(user)
    end

    context 'as a normal user' do
      it 'does not allow to create a group' do
        post :create, params: { group: { title: group.title, members: users_to_add.map(&:login).join(',') } }

        expect(flash[:error]).to eq('Sorry, you are not authorized to create this Class.')
      end
    end

    context 'as an admin' do
      before do
        login(create(:admin_user))
      end

      context 'creating a new group' do
        it 'creates a group with members' do
          post :create, params: { group: { title: 'my_group', members: users_to_add.map(&:login).join(',') } }

          expect(response).to redirect_to(groups_path)
          expect(flash[:success]).to eq("Group 'my_group' successfully updated.")
          expect(Group.where(title: 'my_group')).to exist
        end
      end

      context 'creating a group with invalid data' do
        it 'shows a flash message with the validation error' do
          post :create, params: { group: { title: 'my group', members: users_to_add.map(&:login).join(',') } }

          expect(flash[:error]).to eq("Group can't be saved: Title must not contain invalid characters")
          expect(Group.where(title: 'my group')).not_to exist
        end
      end
    end
  end
end
