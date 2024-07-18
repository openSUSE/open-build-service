class WorkflowRunFilterComponent < ApplicationComponent
  def initialize(token:, selected_filter:, workflow_runs_relation:)
    super

    @count = {
      'success' => workflow_runs_relation.success.count,
      'running' => workflow_runs_relation.running.count,
      'fail' => workflow_runs_relation.fail.count,
      'pull_request' => workflow_runs_relation.pull_request.count,
      'push' => workflow_runs_relation.push.count,
      'tag_push' => workflow_runs_relation.tag_push.count
    }

    @selected_filter = selected_filter
    @token = token
  end
end
