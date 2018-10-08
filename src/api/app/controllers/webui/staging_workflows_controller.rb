class Webui::StagingWorkflowsController < Webui::WebuiController
  before_action :set_project

  def new; end

  def create
    staging_workflow = @project.staging.new
    if staging_workflow.save
      flash[:success] = 'good!!'
      redirect_to :show
    else
      flash[:error] = 'something wrong'
      redirect_to :new
    end
  end
end
