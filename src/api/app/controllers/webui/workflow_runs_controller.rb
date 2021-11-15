class Webui::WorkflowRunsController < Webui::WebuiController
  def index
    @workflow_runs = WorkflowRunPolicy::Scope.new(User.session, WorkflowRun, { token_id: params[:token_id] }).resolve
  end
end
