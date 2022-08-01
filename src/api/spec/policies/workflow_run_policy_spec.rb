require 'rails_helper'

RSpec.describe WorkflowRunPolicy do
  let(:token_user) { create(:confirmed_user, login: 'foo') }
  let(:workflow_token) { create(:workflow_token, executor: token_user) }
  let!(:workflow_run) { create(:workflow_run, token: workflow_token) }

  describe '#resolve' do
    subject { WorkflowRunPolicy::Scope }

    before do
      User.session = token_user
    end

    context 'when the user has permission' do
      it 'returns the workflow runs' do
        expect(subject.new(User.session, WorkflowRun, { token_id: workflow_token.id }).resolve.count).to eq(1)
      end
    end

    context 'when token type is not of type workflow' do
      let(:release_token) { create(:release_token, executor: token_user) }

      it 'raise a not authorized error' do
        expect { subject.new(User.session, WorkflowRun, { token_id: release_token.id }).resolve }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when the token does not exist' do
      it 'does not crash and raises a not authorized error' do
        expect { subject.new(User.session, WorkflowRun, { token_id: nil }).resolve }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when the user does not have permission' do
      before do
        User.session = create(:confirmed_user, login: 'bar')
      end

      it 'raises a not authorized error' do
        expect { subject.new(User.session, WorkflowRun, { token_id: workflow_token.id }).resolve }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  permissions :show? do
    subject { WorkflowRunPolicy }

    let(:anonymous_user) { create(:user_nobody) }
    let(:user_without_permission) { create(:confirmed_user) }

    it { is_expected.to permit(token_user, workflow_run) }
    it { is_expected.not_to permit(anonymous_user, workflow_run) }
    it { is_expected.not_to permit(user_without_permission, workflow_run) }
  end
end
