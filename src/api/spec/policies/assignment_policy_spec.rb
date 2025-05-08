RSpec.describe AssignmentPolicy do
  subject { described_class }

  permissions :create?, :destroy? do
    before do
      Flipper.enable(:foster_collaboration)
    end

    context 'a package collaborator' do
      let(:package_collaborator) { package.maintainers.first }
      let(:package) { create(:package_with_maintainer) }
      let(:assignment) { create(:assignment, assigner: package_collaborator, assignee: package_collaborator, package: package) }

      it { is_expected.to permit(package_collaborator, assignment) }
    end

    context 'a project collaborator' do
      let(:project_collaborator) { create(:confirmed_user) }
      let(:project) { create(:project_with_package, maintainer: project_collaborator) }
      let(:package) { project.packages.first }
      let(:assignment) { build(:assignment, assigner: project_collaborator, assignee: project_collaborator, package: package) }

      it { is_expected.to permit(project_collaborator, assignment) }
    end

    context 'an admin' do
      let(:admin_user) { create(:admin_user) }
      let(:assignment) { build(:assignment) }

      it { is_expected.to permit(admin_user, assignment) }
    end

    context 'any other user' do
      let(:user) { create(:confirmed_user) }
      let(:assignment) { build(:assignment) }

      it { is_expected.not_to permit(user, assignment) }
    end
  end
end
