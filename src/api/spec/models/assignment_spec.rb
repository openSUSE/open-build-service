RSpec.describe Assignment do
  describe '#assignee_is_a_collaborator' do
    subject do
      assignment.assignee_is_a_collaborator
    end

    context 'when the assignee is a package collaborator' do
      let(:package) { create(:package_with_maintainer) }
      let(:assignment) { create(:assignment, package: package, assignee: package.maintainers.first) }

      it { expect(subject).to be true }
    end

    context 'when the assignee is a project collaborator' do
      let(:maintainer) { create(:confirmed_user) }
      let(:project) { create(:project_with_package, maintainer: maintainer) }
      let(:package) { project.packages.first }
      let(:assignment) { create(:assignment, package: package, assignee: maintainer) }

      it { expect(subject).to be true }
    end

    context 'when the assignee is not a collaborator' do
      let(:iggy) { create(:confirmed_user) }
      let(:assignment) { build(:assignment, assignee: iggy) }

      it { expect(subject).to be false }
    end
  end
end
