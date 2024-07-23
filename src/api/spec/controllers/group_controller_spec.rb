RSpec.describe GroupController do
  let(:admin_user) { create(:admin_user) }

  before do
    login admin_user
  end

  describe 'Get show' do
    render_views

    let(:group) { create(:group) }
    let!(:group_maintainer) { create(:group_maintainer, group: group).user }

    context 'when the group exist' do
      before { get :show, params: { title: group.title, format: :xml } }

      it { expect(response).to have_http_status(:success) }

      it 'returns with the xml representation of that group' do
        expect(response.body).to have_css('group > title', text: group.title)
        expect(response.body).to have_css('group > email', text: group.email)
        expect(response.body).to have_css("group > maintainer[userid=#{group_maintainer}]")
      end
    end

    context 'when the group does not exist' do
      before { get :show, params: { title: 'foo', format: :xml } }

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'Get index' do
    render_views

    let!(:groups) { create_list(:group, 3) }

    before { get :index, format: :xml }

    it { expect(response).to have_http_status(:success) }

    it 'returns with the group xml representation' do
      groups.each do |group|
        expect(response.body).to have_css("directory[count=#{groups.count}] > entry[name=#{group.title}]")
      end
    end
  end

  describe 'DELETE #delete' do
    before { delete :delete, params: { title: group.title, format: :xml } }

    shared_examples 'successful group deletion' do
      it 'responds with 200 OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'deletes the record' do
        expect(Group.find_by(id: group.id)).to be_nil
        expect(GroupsUser.where(group_id: group.id)).not_to exist
      end
    end

    context 'group without users' do
      let(:group) { create(:group) }

      it_behaves_like 'successful group deletion'
    end

    context 'group with users' do
      let(:group) { create(:group_with_user) }

      it_behaves_like 'successful group deletion'
    end
  end

  describe 'PUT #update' do
    let(:new_member) { create(:confirmed_user) }
    let(:new_maintainer) { create(:confirmed_user) }
    let(:group) { create(:group) }
    let(:valid_xml) do
      <<~XML
        <group>
          <title>#{group.title}</title>
          <email>tux@openbuildservice.org</email>
          <maintainer userid='#{new_maintainer.login}'/>
          <person>
            <person userid='#{new_maintainer.login}'/>
            <person userid='#{new_member.login}'/>
          </person>
        </group>
      XML
    end

    context 'with a valid request' do
      before { put :update, body: valid_xml, params: { title: group.title, format: :xml } }

      it { expect(response).to have_http_status(:success) }

      it 'updates the group' do
        group.reload
        expect(group.groups_users.pluck(:user_id)).to contain_exactly(new_member.id, new_maintainer.id)
        expect(group.email).to eq('tux@openbuildservice.org')
        expect(group.group_maintainers.pluck(:user_id)).to contain_exactly(new_maintainer.id)
      end
    end

    context 'when the group does not exist' do
      let(:valid_xml) do
        <<~XML
          <group>
            <title>new_group</title>
            <email>tux@openbuildservice.org</email>
            <maintainer userid='#{admin_user.login}'/>
            <person>
              <person userid='#{new_member.login}'/>
            </person>
          </group>
        XML
      end

      before { put :update, body: valid_xml, params: { title: 'new_group', format: :xml } }

      it { expect(response).to have_http_status(:success) }
      it { expect(Group.where(title: 'new_group')).to exist }
    end

    context 'when the group title does not match with the request body' do
      before { put :update, body: valid_xml, params: { title: 'foo', format: :xml } }

      it { expect(response).to have_http_status(:bad_request) }
    end

    context 'when the user does not have permissions for changing the group' do
      let(:user) { create(:confirmed_user) }

      before do
        login(user)
        put :update, body: valid_xml, params: { title: group.title, format: :xml }
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'with an invalid request' do
      # Note the extra " at the end of the XML
      let(:invalid_xml) do
        <<~XML
          <group>
            <title>#{group.title}</title>
            <email>tux@openbuildservice.org</email>
            <maintainer userid='#{new_maintainer.login}'/>
            <person>
              <person userid='#{new_maintainer.login}'/>
              <person userid='#{new_member.login}'/>
            </person>
          </group>"
        XML
      end

      before { put :update, body: invalid_xml, params: { title: group.title, format: :xml } }

      it { expect(response).to have_http_status(:bad_request) }

      it 'does not update the group' do
        group.reload
        expect(group.groups_users).to be_empty
      end
    end
  end
end
