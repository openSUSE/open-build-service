class Webui::StagingWorkflowsController < Webui::WebuiController
  layout 'webui2/webui'

  before_action :require_login, except: [:show]
  before_action :set_bootstrap_views
  before_action :set_project, only: [:new, :create]
  after_action :verify_authorized, except: [:show, :new]

  def new
    if @project.staging
      redirect_to staging_workflow_path(@project.staging)
      return
    end

    @staging_workflow = @project.build_staging
  end

  def create
    staging_workflow = @project.build_staging

    authorize staging_workflow

    if staging_workflow.save
      flash[:success] = "Staging Workflow for #{@project.name} was successfully created"
      redirect_to staging_workflow_path(staging_workflow)
    else
      flash[:error] = "Staging Workflow for #{@project.name} couldn't be created"
      render :new
    end
  end

  def show
    @staging_workflow = StagingWorkflow.find_by(id: params[:id])
    unless @staging_workflow
      redirect_back(fallback_location: root_path)
      flash[:error] = "StagingWorkflow with id = #{params[:id]} doesn't exist"
      return
    end

    @project = @staging_workflow.project
  end

  private

  def set_bootstrap_views
    prepend_view_path('app/views/webui2')
  end
end
