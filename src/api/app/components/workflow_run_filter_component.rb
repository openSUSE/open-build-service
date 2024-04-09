class WorkflowRunFilterComponent < ApplicationComponent
  def initialize(token:, selected_filter:, finder:)
    super

    @count = workflow_runs_count(finder)
    @selected_filter = selected_filter
    @token = token
  end

  def workflow_runs_count(finder)
    counted_workflow_runs = {}
    counted_workflow_runs['success'] = finder.reset.with_status('success').count
    counted_workflow_runs['running'] = finder.reset.with_status('running').count
    counted_workflow_runs['fail'] = finder.reset.with_status('fail').count
    counted_workflow_runs['pull_request'] = finder.reset.with_type('pull_request').count
    counted_workflow_runs['push'] = finder.reset.with_type('push').count
    counted_workflow_runs['tag_push'] = finder.reset.with_type('tag_push').count
    counted_workflow_runs
  end
end
