class Webui::WorkflowRunsController < Webui::WebuiController
  def index
    relation = WorkflowRunPolicy::Scope.new(User.session, WorkflowRun, { token_id: params[:token_id] })
    workflow_runs_finder = WorkflowRunsFinder.new(relation.resolve)

    @workflow_runs = if params[:status]
                       workflow_runs_finder.with_status(params[:status])
                     elsif params[:event_type]
                       workflow_runs_finder.with_event_type(params[:event_type])
                     else
                       workflow_runs_finder.all
                     end

    @workflow_runs = @workflow_runs.page(params[:page])

    @selected_filter = selected_filter
    @token = Token::Workflow.find(params[:token_id])
  end

  def show
    @workflow_run = WorkflowRun.find(params[:id])
    authorize @workflow_run, policy_class: WorkflowRunPolicy

    @token = @workflow_run.token
  end

  def selected_filter
    { event_type: params[:event_type], status: params[:status] }.compact
  end
end
