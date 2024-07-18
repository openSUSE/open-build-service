RSpec.describe Staging::WorkflowPolicy do
  subject { described_class }

  let(:admin) { create(:admin_user) }
  let(:user_nobody) { build(:user_nobody) }
  let(:unauthorized_user) { build(:confirmed_user, login: 'Jerry') }
  let(:staging_workflow) { build(:staging_workflow_with_staging_projects) }

  permissions :new? do
    it { is_expected.not_to permit(unauthorized_user, staging_workflow) }
    it { is_expected.to permit(admin, staging_workflow) }
  end
end
