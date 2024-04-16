class WorkflowRunFilterComponent < ApplicationComponent
  def initialize(token:, selected_filter:, workflow_runs:)
    super

    @count = {
      'success' => workflow_runs.success.count,
      'running' => workflow_runs.running.count,
      'fail' => workflow_runs.fail.count,
      'pull_request' => workflow_runs.pull_request.count,
      'push' => workflow_runs.push.count,
      'tag_push' => workflow_runs.tag_push.count
    }

    @selected_filter = selected_filter
    @token = token
  end
end
