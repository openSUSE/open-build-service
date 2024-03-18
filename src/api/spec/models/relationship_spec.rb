RSpec.describe Relationship do
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:global_role) { create(:role, title: 'global_role', global: true) }
  let(:normal_role) { create(:role, title: 'normal_role', global: false) }

  describe '.add_user' do
    subject { Relationship.add_user(project, user, role, true, true) }

    let(:role) { normal_role }
    let(:user) { create(:confirmed_user, :with_home, login: 'other_user') }
    let(:project) { user.home_project }

    before do
      login(admin_user)
    end

    context 'with a global role' do
      let(:role) { global_role }

      it { expect { subject }.to raise_error(Relationship::AddRole::SaveError, /tried to set global role/) }
    end

    context 'with an already existing relationship' do
      before do
        project.relationships.create(user: user, role: role)
      end

      it { expect { subject }.to raise_error(Relationship::AddRole::SaveError, 'Relationship already exists') }
    end

    context 'with invalid relationship data' do
      skip('This is imposible to happen with the actual validations and how the object is created')
    end

    context 'with banned user' do
      subject { Relationship.add_user(project, nobody, role, true, true) }

      let(:nobody) { create(:user_nobody) }

      it { expect { subject }.to raise_error(NotFoundError, "Couldn't find user #{nobody.login}") }
    end

    context 'with valid data' do
      before do
        subject
      end

      it { expect { project.store }.to change(Relationship, :count).by(1) }
      it { expect { project.store }.to change(Event::RelationshipCreate, :count).by(1) }
    end
  end

  describe '.add_group' do
    subject { Relationship.add_group(project, group, role, true, true) }

    let(:role) { normal_role }
    let(:user) { admin_user }
    let(:project) { user.home_project }
    let(:group) { create(:group) }

    before do
      login(admin_user)
    end

    context 'with a global role' do
      let(:role) { global_role }

      it { expect { subject }.to raise_error(Relationship::AddRole::SaveError, /tried to set global role/) }
    end

    context 'with an already existing relationship' do
      before do
        project.relationships.create(group: group, role: role)
      end

      it { expect { subject }.to raise_error(Relationship::AddRole::SaveError, 'Relationship already exists') }
    end

    context 'with invalid relationship data' do
      skip('This is imposible to happen with the actual validations and how the object is created')
    end

    context 'with valid data' do
      before do
        subject
      end

      it { expect { project.store }.to change(Relationship, :count).by(1) }
      it { expect { project.store }.to change(Event::RelationshipCreate, :count).by(1) }
    end
  end

  describe '.forbidden_project_ids' do
    let(:confirmed_user) { create(:confirmed_user) }
    let(:project) { create(:forbidden_project) }
    let(:allowed_users) { create(:group_with_user, user: confirmed_user) }

    context 'for admins' do
      before do
        login(admin_user)
      end

      it { expect(Relationship.forbidden_project_ids).to eq([0]) }
    end

    context 'for users' do
      let(:confirmed_user2) { create(:confirmed_user) }

      before do
        login(confirmed_user)
        create(:relationship_project_user, project: project, user: confirmed_user)
        login(confirmed_user2)
      end

      it { expect(Relationship.forbidden_project_ids).to include(project.id) }
    end

    context 'for whitelisted users' do
      before do
        login(confirmed_user)
        create(:relationship_project_user, project: project, user: confirmed_user)
      end

      it { expect(Relationship.forbidden_project_ids).not_to include(project.id) }
    end

    context 'for users in whitelisted groups' do
      before do
        login(confirmed_user)
        create(:relationship_project_group, project: project, group: allowed_users)
      end

      it { expect(Relationship.forbidden_project_ids).not_to include(project.id) }
    end
  end

  xit '.discard_cache'
end
