class Webui::WorkflowRunsController < Webui::WebuiController
  def index
    relation = WorkflowRunPolicy::Scope.new(User.session, WorkflowRun, { token_id: params[:token_id] })
    @workflow_runs_finder = WorkflowRunsFinder.new(relation.resolve)
    @request_action = params[:request_action] if params[:request_action].present? && params[:request_action] != 'all'
    # TODO: The pull/merge request dropdown should accept multiple selections

    status = %w[success running fail].select { |f| params[f] }
    event_types = %w[pull_request push tag_push].select { |f| params[f] }
    request_action = []
    request_action << params[:request_action] unless params[:request_action] == 'all'

    @workflow_runs = @workflow_runs_finder
                     .with_status(status)
                     .with_type(event_types)
                     .with_request_action(request_action)
                     .with_event_source_name(params[:pr_mr], 'pr_mr')
                     .with_event_source_name(params[:commit_sha], 'commit')
                     .all

    @workflow_runs = @workflow_runs.page(params[:page])

    @selected_filter = { status: status, event_type: event_types, request_action: request_action, pr_mr: params[:pr_mr], commit_sha: params[:commit_sha] }
    @token = Token::Workflow.find(params[:token_id])
  end

  def show
    @workflow_run = WorkflowRun.find(params[:id])
    authorize @workflow_run, policy_class: WorkflowRunPolicy

    @token = @workflow_run.token
  end
end
