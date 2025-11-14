RSpec.describe AssignmentPolicy do
  subject { described_class }

  permissions :create?, :destroy? do
    before do
      Flipper.enable(:foster_collaboration)
    end

    context 'as a package maintainer' do
      let(:package_maintainer) { package.maintainers.first }
      let(:package) { create(:package_with_maintainer) }
      let(:assignment) { build(:assignment, assigner: package_maintainer, package: package) }

      it { is_expected.to permit(package_maintainer, assignment) }
    end

    context 'as project maintainer' do
      let(:project_maintainer) { create(:confirmed_user) }
      let(:project) { create(:project_with_package, maintainer: project_maintainer) }
      let(:package) { project.packages.first }
      let(:assignment) { build(:assignment, assigner: project_maintainer, package: package) }

      it { is_expected.to permit(project_maintainer, assignment) }
    end

    context 'as a admin user' do
      let(:admin_user) { create(:admin_user) }
      let(:package) { create(:package) }
      let(:assignment) { build(:assignment, assigner: admin_user, package: package) }

      it { is_expected.to permit(admin_user, assignment) }
    end

    context 'as a bugowner' do
      let(:user) { create(:confirmed_user) }
      let!(:bugowner_relationship) { create(:relationship_package_user_as_bugowner, user: user, package: package) }
      let(:package) { create(:package) }
      let(:assignment) { build(:assignment, assigner: user, package: package) }

      it { is_expected.to permit(user, assignment) }
    end

    context 'as a reviewer' do
      let(:user) { create(:confirmed_user) }
      let!(:reviewer_relationship) { create(:relationship_package_user_as_reviewer, user: user, package: package) }
      let(:package) { create(:package) }
      let(:assignment) { build(:assignment, assigner: user, package: package) }

      it { is_expected.to permit(user, assignment) }
    end

    context 'a user without any role' do
      let(:user) { create(:confirmed_user) }
      let(:package) { create(:package) }
      let(:assignment) { build(:assignment, assigner: user, package: package) }

      it { is_expected.not_to permit(user, assignment) }
    end
  end
end
