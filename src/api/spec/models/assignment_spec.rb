RSpec.describe Assignment do
  describe '#assignee_has_required_role_to_be_assigned?' do
    subject do
      build(:assignment, package: package, assignee: user)
    end

    let(:project) { create(:project_with_package) }
    let(:package) { project.packages.first }
    let(:user) { create(:confirmed_user) }

    context 'when the assignee is a package maintainer' do
      let!(:relationship_package_maintainer) { create(:relationship_package_user, package: package, user: user) }

      it { expect(subject).to be_valid }
    end

    context 'when the assignee is a project maintainer' do
      let!(:relationship_project_maintainer) { create(:relationship_project_user, project: project, user: user) }

      it { expect(subject).to be_valid }
    end

    context 'when the assignee is a package bugowner' do
      let!(:bugowner_relationship) { create(:relationship_package_user_as_bugowner, user: user, package: package) }

      it { expect(subject).to be_valid }
    end

    context 'when the assignee is a package reviewer' do
      let!(:reviewer_relationship) { create(:relationship_package_user_as_reviewer, user: user, package: package) }

      it { expect(subject).to be_valid }
    end

    context 'when the assignee has no role' do
      it { expect(subject).not_to be_valid }
    end
  end
end
