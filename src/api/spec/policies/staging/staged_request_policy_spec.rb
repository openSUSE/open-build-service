RSpec.describe Staging::StagedRequestPolicy do
  subject { described_class }

  let(:admin) { create(:admin_user) }
  let(:authorized_user) { create(:confirmed_user, login: 'Tom') }
  let(:unauthorized_user) { create(:confirmed_user, login: 'Jerry') }
  let!(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: admin.home_project) }
  let!(:add_member) { create(:groups_user, user: authorized_user, group: staging_workflow.managers_group) }

  permissions :create?, :destroy? do
    it { is_expected.not_to permit(unauthorized_user, staging_workflow) }
    it { is_expected.to permit(admin, staging_workflow) }
    it { is_expected.to permit(authorized_user, staging_workflow) }
  end
end
