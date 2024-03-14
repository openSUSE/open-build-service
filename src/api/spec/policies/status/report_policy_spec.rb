RSpec.describe Status::ReportPolicy do
  subject { described_class }

  let(:anonymous_user) { create(:user_nobody) }

  RSpec.shared_context 'write permissions' do
    context 'status report for repository' do
      let(:project) { create(:project_with_repository) }
      let(:status_report) { create(:status_report, checkable: project.repositories.first) }

      context "users that don't belong to the repository project" do
        let(:user) { create(:confirmed_user) }

        it { is_expected.not_to permit(user, status_report) }
      end

      context 'user is admin' do
        let(:user) { create(:admin_user) }

        it { is_expected.to permit(user, status_report) }
      end

      context 'user is project maintainer' do
        let(:user) { create(:confirmed_user) }
        let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

        it { is_expected.to permit(user, status_report) }
      end

      context 'user is member of project maintainer group' do
        let(:user) { create(:user) }
        let(:group) { create(:group_with_user, user: user) }
        let!(:relationship) { create(:relationship_project_group, group: group, project: project) }

        it { is_expected.to permit(user, status_report) }
      end
    end

    context 'status report for request' do
      let(:source_project) { create(:project_with_package) }
      let(:target_project) { create(:project) }
      let(:bs_request) do
        create(:bs_request_with_submit_action,
               source_package: source_project.packages.first,
               target_project: target_project)
      end
      let(:status_report) { create(:status_report, checkable: bs_request) }

      context "users that don't belong to the repository project" do
        let(:user) { create(:confirmed_user) }

        it { is_expected.not_to permit(user, status_report) }
      end

      context 'user is admin' do
        let(:user) { create(:admin_user) }

        it { is_expected.to permit(user, status_report) }
      end

      context 'user is project maintainer' do
        let(:user) { create(:confirmed_user) }
        let!(:relationship) { create(:relationship_project_user, user: user, project: target_project) }

        it { is_expected.to permit(user, status_report) }
      end

      context 'user is member of project maintainer group' do
        let(:user) { create(:user) }
        let(:group) { create(:group_with_user, user: user) }
        let!(:relationship) { create(:relationship_project_group, group: group, project: target_project) }

        it { is_expected.to permit(user, status_report) }
      end
    end
  end

  permissions :create? do
    include_context 'write permissions'
  end

  permissions :update? do
    include_context 'write permissions'
  end

  permissions :destroy? do
    include_context 'write permissions'
  end
end
