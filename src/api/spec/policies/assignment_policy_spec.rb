RSpec.describe AssignmentPolicy do
  subject { described_class }

  permissions :create?, :destroy? do
    before do
      Flipper.enable(:foster_collaboration)
    end

    context 'a package maintainer' do
      let(:package_maintainer) { package.maintainers.first }
      let(:package) { create(:package_with_maintainer) }
      let(:assignment) { create(:assignment, assigner: package_maintainer, assignee: package_maintainer, package: package) }

      it { is_expected.to permit(package_maintainer, assignment) }
    end

    context 'a project maintainer' do
      let(:project_maintainer) { create(:confirmed_user) }
      let(:project) { create(:project_with_package, maintainer: project_maintainer) }
      let(:package) { project.packages.first }
      let(:assignment) { build(:assignment, assigner: project_maintainer, assignee: project_maintainer, package: package) }

      it { is_expected.to permit(project_maintainer, assignment) }
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
