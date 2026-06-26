# rubocop:disable RSpec/DescribeClass
RSpec.describe 'workflows' do
  # rubocop:enable RSpec/DescribeClass
  include_context 'rake'

  let!(:admin_user) { create(:admin_user, login: 'Admin') }
  let!(:project_iggy_hello_world_pr1) { create(:project, name: 'home:Iggy:iggy:hello_world:PR-1') }
  let!(:project_iggy_hello_world_pr2) { create(:project, name: 'home:Iggy:iggy:hello_world:PR-2') }
  let!(:project_iggy_test_pr3) { create(:project, name: 'home:Iggy:iggy:test:PR-3') }

  let!(:workflow_run_running_pr_opened) { create(:workflow_run, repository_owner: 'iggy', repository_name: 'hello_world') }
  let!(:workflow_run_succeeded_pr_opened) { create(:workflow_run, :succeeded, repository_owner: 'iggy', repository_name: 'hello_world') }
  let!(:workflow_run_failed_pr_opened) { create(:workflow_run, :failed, repository_owner: 'iggy', repository_name: 'hello_world') }

  let!(:workflow_run_running_pr_closed) { create(:workflow_run, :pull_request_closed, repository_owner: 'iggy', repository_name: 'hello_world', event_source_name: 1) }
  let!(:another_workflow_run_running_pr_closed) { create(:workflow_run, :pull_request_closed, repository_owner: 'iggy', repository_name: 'hello_world', event_source_name: 2) }
  let!(:workflow_run_running_pr_merge) { create(:workflow_run_gitlab, :pull_request_merged, repository_owner: 'iggy', repository_name: 'hello_world', event_source_name: 3) }

  describe 'cleanup_non_closed_projects' do
    let(:task) { 'dev:workflows:cleanup_non_closed_projects' }

    it { expect { rake_task.invoke }.to change(WorkflowRun.where(status: 'running'), :count).from(4).to(1) }

    # The workflow runs defined above will create two target projects that should be deleted
    # because the corresponding PR or MR are closed/merged.
    it { expect { rake_task.invoke }.to change(Project, :count).from(3).to(1) }
  end
end
