require 'rails_helper'

RSpec.describe Webui::WorkflowRunsController do
  describe 'GET #index' do
    let(:token_user) { create(:confirmed_user) }
    let(:workflow_token) { create(:workflow_token, executor: token_user) }
    let!(:workflow_run) { create(:workflow_run, token: workflow_token) }

    before do
      login token_user
    end

    context 'when action_filter is not available' do
      before do
        get :index, params: { token_id: workflow_token.id }
      end

      it { expect(assigns(:workflow_runs).count).to eq(1) }
    end

    context 'when action_filter is available' do
      it 'finds workflow runs when the action is available' do
        get :index, params: { token_id: workflow_token.id, request_action: 'opened', generic_event_type: 'pull_request' }

        expect(assigns(:workflow_runs).count).to eq(1)
        expect(assigns(:request_action)).to eq('opened')
      end

      it 'does not find workflow runs when action is not available' do
        get :index, params: { token_id: workflow_token.id, request_action: 'closed', generic_event_type: 'pull_request' }

        expect(assigns(:workflow_runs).count).to eq(0)
        expect(assigns(:request_action)).to eq('closed')
      end
    end
  end
end
