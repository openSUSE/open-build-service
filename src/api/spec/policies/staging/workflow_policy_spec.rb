require 'rails_helper'

RSpec.describe Staging::WorkflowPolicy do
  let(:admin) { create(:admin_user) }
  let(:user_nobody) { build(:user_nobody) }
  let(:unauthorized_user) { build(:confirmed_user, login: 'Jerry') }
  let(:staging_workflow) { build(:staging_workflow_with_staging_projects) }

  subject { Staging::WorkflowPolicy }

  permissions :new? do
    it { is_expected.not_to permit(unauthorized_user, staging_workflow) }
    it { is_expected.to permit(admin, staging_workflow) }
  end

  it "doesn't permit anonymous user by default" do
    expect { described_class.new(user_nobody, staging_workflow) }
      .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: ApplicationPolicy::ANONYMOUS_USER)))
  end

  it 'permits anonymous user when ensure_logged_in == false' do
    expect { described_class.new(user_nobody, staging_workflow, ensure_logged_in: false) }.not_to raise_error
  end
end
