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
        get :index, params: { token_id: workflow_token.id, request_action: 'opened', pull_merge_request: 1 }

        expect(assigns(:workflow_runs).count).to eq(1)
      end

      it 'does not find workflow runs when action is not available' do
        # TODO: Check this pull_merge_requet parameter...
        get :index, params: { token_id: workflow_token.id, request_action: 'closed', pull_merge_request: 1 }

        expect(assigns(:workflow_runs).count).to eq(0)
      end
    end

    context 'multiple filters' do
      let!(:pull_request_1_workflow_run) { create(:workflow_run, :succeeded) }
      let(:token) { pull_request_1_workflow_run.token }
      let!(:pull_request_2_workflow_run) { create(:workflow_run, :succeeded, event_source_name: '2', token: token) }
      let!(:closed_pull_request_workflow_run) { create(:workflow_run, :pull_request_closed, token: token) }
      let!(:running_push_workflow_run) { create(:workflow_run, :running, :push, token: token) }
      let!(:succeeded_tag_push_workflow_run) { create(:workflow_run_gitlab, :failed, :tag_push, token: token) }

      before do
        login pull_request_1_workflow_run.token.executor
      end

      describe 'when having no filters selected' do
        # rubocop:disable RSpec/ExampleLength
        it 'shows all the workflow runs' do
          get :index, params: { token_id: token.id, pr_mr: '', commit_sha: '' }

          expect(assigns[:workflow_runs]).to contain_exactly(pull_request_1_workflow_run,
                                                             pull_request_2_workflow_run,
                                                             running_push_workflow_run,
                                                             closed_pull_request_workflow_run,
                                                             succeeded_tag_push_workflow_run)
        end
        # rubocop:enable RSpec/ExampleLength
      end

      describe 'when having multiple filters selected' do
        it 'shows all the matching workflow runs' do
          get :index, params: { token_id: token.id, success: 1, running: 1, pull_request: 1, push: 1, request_action: 'opened', pr_mr: 1 }

          expect(assigns[:workflow_runs]).to contain_exactly(pull_request_1_workflow_run)
        end
      end
    end
  end
end
