require 'rails_helper'

RSpec.describe WorkflowRunPolicy do
  describe '#resolve' do
    subject { WorkflowRunPolicy::Scope }

    let(:token_user) { create(:confirmed_user) }
    let(:workflow_token) { create(:workflow_token, user: token_user) }
    let!(:workflow_run) { create(:workflow_run, token: workflow_token) }

    context 'when the user has permission' do
      before do
        User.session = token_user
      end

      it 'returns the workflow runs' do
        expect(subject.new(token_user, WorkflowRun, { token_id: workflow_token.id }).resolve.count).to eq(1)
      end
    end

    context 'when the user does not have permission' do
      let(:another_user) { create(:confirmed_user) }

      before do
        User.session = another_user
      end

      it 'raises a not authorized error' do
        expect { subject.new(another_user, WorkflowRun, { token_id: workflow_token.id }).resolve }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'when token type is not of type workflow' do
      let(:release_token) { create(:release_token, user: token_user) }

      before do
        User.session = token_user
      end

      it 'raise a not authorized error' do
        expect { subject.new(token_user, WorkflowRun, { token_id: release_token.id }).resolve }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end
