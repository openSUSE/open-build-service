class WorkflowRunFilterComponent < ApplicationComponent
  def initialize(token:, selected_filter:)
    super

    @count = {
      'success' => WorkflowRun.success.count,
      'running' => WorkflowRun.running.count,
      'fail' => WorkflowRun.fail.count,
      'pull_request' => WorkflowRun.pull_request.count,
      'push' => WorkflowRun.push.count,
      'tag_push' => WorkflowRun.tag_push.count
    }
    @selected_filter = selected_filter
    @token = token
  end
end
