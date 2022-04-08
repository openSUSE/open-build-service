class WorkflowRunFilterComponent < ApplicationComponent
  def initialize(token:, selected_filter:, finder:)
    super

    @count = workflow_runs_count(finder)
    @selected_filter = selected_filter
    @token = token
  end

  def workflow_runs_count(finder)
    counted_workflow_runs = {}
    counted_workflow_runs['success'] = finder.succeeded.count
    counted_workflow_runs['running'] = finder.running.count
    counted_workflow_runs['fail'] = finder.failed.count
    counted_workflow_runs.merge(finder.group_by_generic_event_type)
  end
end
