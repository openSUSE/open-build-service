class Webui::StagingWorkflowsController < Webui::WebuiController
  before_action :set_project

  def new; end

  def create
    staging_workflow = @project.staging.new
    if staging_workflow.save
      flash[:success] = "Staging Workflow for #{@project.name} was successfully created"
      redirect_to :show
    else
      flash[:error] = "Staging Workflow for #{@project.name} couldn't be created"
      redirect_to :new
    end
  end
end
