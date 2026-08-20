RSpec.describe Webui::GroupsController do
  let(:group) { create(:group) }
  let(:admin) { create(:admin_user) }

  describe '#set_group' do
    it 'redirects to root_path if group does not exist' do
      get :show, params: { title: 'Foobar' }
      expect(flash[:error]).to eq("Group 'Foobar' not found")
      expect(response).to redirect_to(root_path)
    end
  end

  describe '#set_members' do
    before do
      login(admin)

      post :create, params: { group: { title: 'hans', members: '_nobody_' } }
    end

    it "shows a flash message with the validation error and doesn't create the group" do
      expect(flash[:error]).to eq("Group can't be saved: User _nobody_ not found")
      expect(Group.where(title: 'hans')).not_to exist
    end
  end

  describe 'GET #show' do
    it 'assigns @group' do
      get :show, params: { title: group.title }
      expect(response).to have_http_status(:success)
      expect(assigns(:group)).to eq(group)
    end
  end

  describe 'GET #autocomplete' do
    let(:user) { create(:confirmed_user) }
    let(:another_group) { create(:group, title: "#{group.title}-#{SecureRandom.hex}") }

    before do
      login(user)
    end

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

  describe 'POST #create' do
    let(:title) { 'my_group' }
    let(:users_to_add) { create_list(:confirmed_user, 3).map(&:login).join(',') }

    before do
      login(admin)

      post :create, params: { group: { title: title, members: users_to_add } }
    end

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
  end

  describe 'PUT #update' do
    let(:email) { 'example@example.com' }

    before do
      login(admin)
      put :update, params: { title: group.title, group: { email: email } }
    end

    it 'updates the group' do
      expect(flash[:success]).to eq('Group email successfully updated')
      expect(group.reload.email).to eq(email)
    end

    context 'when the attribute is empty' do
      let(:email) { '' }

      it 'removes the attribute' do
        expect(flash[:success]).to eq('Group email successfully updated')
        expect(group.reload.email).to be_empty
      end
    end
  end
end
