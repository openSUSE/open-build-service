class Webui::WorkflowRunsController < Webui::WebuiController
  def index
    @workflow_runs = WorkflowRunPolicy::Scope.new(User.session, WorkflowRun, { token_id: params[:token_id] }).resolve.page(params[:page])
    @token = Token::Workflow.find(params[:token_id])
  end

  def show
    @workflow_run = WorkflowRun.find(params[:id])
    authorize @workflow_run, policy_class: WorkflowRunPolicy

    @token = @workflow_run.token
  end
end
