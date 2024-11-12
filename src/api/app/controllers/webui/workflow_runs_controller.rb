class Webui::WorkflowRunsController < Webui::WebuiController
  include Webui::NotificationsHandler

  def index
    # TODO: The pull/merge request dropdown should accept multiple selections

    request_action = []
    request_action << params[:request_action] unless params[:request_action] == 'all'

    relation = WorkflowRunPolicy::Scope.new(User.session, WorkflowRun, { token_id: params[:token_id] }).resolve
    relation = relation.with_statuses(status_params) if status_params.any?
    relation = relation.with_types(event_type_params) if event_type_params.any?
    relation = relation.with_actions(request_action) if request_action.any?
    relation = relation.with_event_source_name(params[:pr_mr]) if params[:pr_mr].present?
    relation = relation.with_event_source_name(params[:commit_sha]) if params[:commit_sha].present?

    @workflow_runs_relation = relation
    @workflow_runs = relation.all.page(params[:page])

    @selected_filter = { status: status_params, event_type: event_type_params, request_action: request_action, pr_mr: params[:pr_mr], commit_sha: params[:commit_sha] }
    @token = Token::Workflow.find(params[:token_id])
  end

  def show
    @workflow_run = WorkflowRun.find(params[:id])
    authorize @workflow_run, policy_class: WorkflowRunPolicy

    @current_notification = handle_notification
    @token = @workflow_run.token
  end

  private

  def status_params
    @status_params ||= %w[success running fail].select { |f| params[f] }
  end

  def event_type_params
    @event_type_params ||= %w[pull_request push tag_push].select { |f| params[f] }
  end
end
