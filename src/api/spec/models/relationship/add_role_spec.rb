RSpec.describe Relationship::AddRole do
  subject { Relationship::AddRole.new(package_or_project, role, options).add_role }

  let(:user) { create(:confirmed_user) }
  let(:role) { create(:role) }

  shared_examples 'user' do
    context 'add user' do
      let(:options) { { user: user } }

      it 'adds a relationship' do
        subject
        expect(package_or_project.relationships.size).to eq(1)
        expect(package_or_project.relationships.first.user).to eq(user)
      end
    end
  end

  shared_examples 'group' do
    context 'add group' do
      let(:group) { create(:group) }
      let(:options) { { group: group } }

      it 'adds a relationship' do
        subject
        expect(package_or_project.relationships.size).to eq(1)
        expect(package_or_project.relationships.first.group).to eq(group)
      end
    end
  end

  describe '.add_role' do
    context 'with package' do
      let(:package_or_project) { create(:package) }

      it_behaves_like 'user'
      it_behaves_like 'group'
    end

    context 'with project' do
      let(:package_or_project) { create(:project) }

      it_behaves_like 'user'
      it_behaves_like 'group'
    end
  end
end
