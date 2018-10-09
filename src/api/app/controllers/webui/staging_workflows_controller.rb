class Webui::StagingWorkflowsController < Webui::WebuiController
  layout 'webui2/webui'

  before_action :set_bootstrap_views

  before_action :set_project, only: [:new, :create]

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

  def show
    @staging_workflow = StagingWorkflow.find_by(id: params[:id])
    @project = @staging_workflow.project
  end

  private

  def set_bootstrap_views
    prepend_view_path('app/views/webui2')
  end
end
