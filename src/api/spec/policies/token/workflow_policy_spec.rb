require 'rails_helper'

RSpec.describe Token::WorkflowPolicy, beta: true do
  subject { described_class }

  describe '#create' do
    context 'user inactive' do
      let(:user_token) { create(:workflow_token, user: user) }

      include_examples 'non-active users cannot use a token'
    end

    # As a workflow token is not tied to a package, any user can create one as long as their account is active.
    context 'user active' do
      let(:user) { create(:confirmed_user, login: 'foo') }
      let(:user_token) { create(:workflow_token, user: user) }

      permissions :create? do
        it { expect(subject).to permit(user, user_token) }
      end
    end
  end
end
