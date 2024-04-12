class Webui::WorkflowRunsController < Webui::WebuiController
  def index
    relation = WorkflowRunPolicy::Scope.new(User.session, WorkflowRun, { token_id: params[:token_id] })
    @workflow_runs_finder = WorkflowRunsFinder.new(relation.resolve)
    @request_action = params[:request_action] if params[:request_action].present? && params[:request_action] != 'all'
    # TODO: The pull/merge request dropdown should accept multiple selections
    filter = WorkflowRunFilter.new(params)
    @workflow_runs = @workflow_runs_finder
                     .with_status(filter.status)
                     .with_type(filter.event_types)
                     .with_request_action(filter.request_action)
                     .with_event_source_name(filter.pr_mr, 'pr_mr')
                     .with_event_source_name(filter.commit, 'commit')
                     .all

    @workflow_runs = @workflow_runs.page(params[:page])

    @selected_filter = filter
    @token = Token::Workflow.find(params[:token_id])
  end

  def show
    @workflow_run = WorkflowRun.find(params[:id])
    authorize @workflow_run, policy_class: WorkflowRunPolicy

    @token = @workflow_run.token
  end
end
