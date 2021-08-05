require 'rails_helper'

RSpec.describe Token::WorkflowPolicy, beta: true do
  subject { described_class }

  describe '#trigger' do
    let(:user_token) { create(:workflow_token, user: user) }

    context 'user inactive' do
      include_examples 'non-active users cannot trigger a token'
    end

    # As a workflow token is not tied to a package, any user can create one as long as their account is active.
    context 'user active' do
      let(:user) { create(:confirmed_user, login: 'foo') }

      permissions :trigger? do
        it { expect(subject).to permit(user, user_token) }
      end
    end
  end
end
