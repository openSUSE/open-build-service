require Rails.root.join('db/data/20230620110143_backfill_scm_vendor_and_hook_event_in_workflow_run.rb')

RSpec.describe BackfillScmVendorAndHookEventInWorkflowRun, type: :migration do
  describe 'up' do
    subject { BackfillScmVendorAndHookEventInWorkflowRun.new.up }

    let(:request_headers) do
      <<~END_OF_HEADERS
        HTTP_X_GITLAB_EVENT: Push Hook
      END_OF_HEADERS
    end
    # Simulate old workflow runs' entries where scm_vendor and hook_event where nil
    let!(:github_workflow_run) { create(:workflow_run, scm_vendor: nil, hook_event: nil) }
    let!(:gitlab_workflow_run) { create(:workflow_run, request_headers: request_headers, scm_vendor: nil, hook_event: nil) }
    # Simulate new workflow run entry where scm_vendor and hook_event was set in creation time
    let!(:gitea_workflow_run) { create(:workflow_run, scm_vendor: 'gitea', hook_event: 'push') }

    before do
      subject
    end

    it 'backfill all the expected fields' do
      expect(WorkflowRun.where(scm_vendor: nil).count).to eq(0)
      expect(WorkflowRun.where(hook_event: nil).count).to eq(0)
    end

    it 'fills the first workflow run with GitHub data' do
      expect(github_workflow_run.reload.scm_vendor).to eq('github')
      expect(github_workflow_run.reload.hook_event).to eq('pull_request')
    end

    it 'fills the second workflow run with GitLab data' do
      expect(gitlab_workflow_run.reload.scm_vendor).to eq('gitlab')
      expect(gitlab_workflow_run.reload.hook_event).to eq('Push Hook')
    end

    it 'keeps the Gitea data in the third workflow run' do
      expect(gitea_workflow_run.reload.scm_vendor).to eq('gitea')
      expect(gitea_workflow_run.reload.hook_event).to eq('push')
    end
  end
end
