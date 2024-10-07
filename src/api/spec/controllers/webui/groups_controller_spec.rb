RSpec.describe Webui::GroupsController do
  let(:group) { create(:group) }

  # except [:show, :tokens, :autocomplete]
  it { is_expected.to use_before_action(:require_login) }
  # except: [:show, :autocomplete, :tokens]
  it { is_expected.to use_after_action(:verify_authorized) }

  describe 'GET show' do
    it 'assigns @group' do
      get :show, params: { title: group.title }
      expect(response).to have_http_status(:success)
      expect(assigns(:group)).to eq(group)
    end

    it 'redirects to root_path if group does not exist' do
      get :show, params: { title: 'Foobar' }
      expect(flash[:error]).to eq("Group 'Foobar' does not exist")
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'GET autocomplete' do
    let(:another_group) { create(:group, title: "#{group.title}-#{SecureRandom.hex}") }

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

  describe 'POST create' do
    let(:title) { 'my_group' }
    let(:users_to_add) { create_list(:user, 3).map(&:login).join(',') }

    before do
      login(login_as)

      post :create, params: { group: { title: title, members: users_to_add } }
    end

    context 'as a normal user' do
      let(:login_as) { create(:user) }

      it 'does not allow to create a group' do
        expect(flash[:error]).to eq('Sorry, you are not authorized to create this group.')
        expect(Group.where(title: title)).not_to exist
      end
    end

    context 'as an admin' do
      let(:login_as) { create(:admin_user) }

      context 'with valid title and valid users' do
        it 'creates a group with members' do
          expect(response).to redirect_to(groups_path)
          expect(flash[:success]).to eq("Group '#{title}' successfully created.")
          expect(Group.where(title: title)).to exist
        end
      end

      context 'with an invalid title' do
        let(:title) { 'my group' }

        it "shows a flash message with the validation error and doesn't create the group" do
          expect(flash[:error]).to eq("Group can't be saved: Title must not contain invalid characters")
          expect(Group.where(title: title)).not_to exist
        end
      end

      context 'with a nonexistent user' do
        let(:users_to_add) { 'non_existent_user' }

        it "shows a flash message with the validation error and doesn't create the group" do
          expect(flash[:error]).to eq("Group can't be saved: Couldn't find User with login = #{users_to_add}")
          expect(Group.where(title: title)).not_to exist
        end
      end
    end
  end

  describe 'GET #edit' do
    let(:title) { group.title }

    before do
      login(login_as)
      get :edit, params: { title: title }
    end

    context 'as a normal user' do
      let(:login_as) { create(:user) }

      it 'does not allow to edit the group' do
        expect(flash[:error]).to eq('Sorry, you are not authorized to update this group.')
      end
    end

    context 'as an admin' do
      let(:login_as) { create(:admin_user) }

      it { expect(assigns(:group)).to eq(group) }

      context 'which an inexistent group' do
        let(:title) { 'no_real_title' }

        it 'does not allow to edit the group' do
          expect(flash[:error]).to eq("The group doesn't exist")
        end
      end
    end
  end

  describe 'PUT #update' do
    let(:title) { group.title }

    before do
      login(login_as)
      put :update, params: { title: title, group: { email: email } }
    end

    context 'as a normal user' do
      let(:login_as) { create(:user) }
      let(:email) { 'new_email@example.com' }

      it 'does not allow to update the group' do
        expect(flash[:error]).to eq('Sorry, you are not authorized to update this group.')
        expect(group.reload.email).not_to eq(email)
      end
    end

    context 'as an admin' do
      let(:login_as) { create(:admin_user) }

      context 'which an inexistent group' do
        let(:title) { 'no_real_title' }
        let(:email) { 'new_email@example.com' }

        it 'does not allow to edit the group' do
          expect(flash[:error]).to eq("The group doesn't exist")
        end
      end

      context 'when the email is empty' do
        let(:email) { nil }

        it 'updates the email' do
          expect(flash[:success]).to eq('Group email successfully updated')
          expect(group.reload.email).to be_empty
        end
      end

      context 'when the email is not empty' do
        let(:email) { 'new_email@example.com' }

        it 'updates the email' do
          expect(response).to redirect_to(groups_path)
          expect(flash[:success]).to eq('Group email successfully updated')
          expect(group.reload.email).to eq(email)
        end
      end

      context 'when the email have the wrong format' do
        let(:email) { 'is_not_an_email' }

        it 'is not updated' do
          expect(flash[:error]).to eq("Couldn't update group: Email must be a valid email address")
        end
      end
    end
  end
end
