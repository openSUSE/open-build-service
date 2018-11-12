class Webui::Staging::WorkflowsController < Webui::WebuiController
  layout 'webui2/webui'

  before_action :require_login, except: [:show]
  before_action :set_bootstrap_views
  before_action :set_project, only: [:new, :create]
  before_action :set_staging_workflow, except: [:new, :create]
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
    @project = @staging_workflow.project
    @staging_projects = @staging_workflow.staging_projects.includes(:staged_requests).reject { |project| project.overall_state == :empty }
    @unassigned_requests = @staging_workflow.unassigned_requests.first(5)
    @more_unassigned_requests = @staging_workflow.unassigned_requests.count - @unassigned_requests.size
    @ready_requests = @staging_workflow.ready_requests.first(5)
    @more_ready_requests = @staging_workflow.ready_requests.count - @ready_requests.size
    @ignored_requests = @staging_workflow.ignored_requests.first(5)
    @more_ignored_requests = @staging_workflow.ignored_requests.count - @ignored_requests.size
    @empty_projects = @staging_workflow.staging_projects.without_staged_requests
  end

  def edit
    authorize @staging_workflow

    @project = @staging_workflow.project
  end

  def destroy
    @staging_workflow = ::Staging::Workflow.find_by(id: params[:id])
    authorize @staging_workflow
    @project = @staging_workflow.project

    # attached staging projects get nullified by default but we want to
    # allow to destroy manually by setting a checkbox
    @staging_workflow.staging_projects.where(id: params[:staging_project_ids]).destroy_all

    if @staging_workflow.destroy
      flash[:success] = "Staging Workflow for #{@project.name} was successfully deleted."
      render js: "window.location='#{project_show_path(@project)}'"
    else
      flash[:error] = "Staging Workflow for #{@project.name} couldn't be deleted: #{@staging_workflow.errors.full_messages.to_sentence}."
      render js: "window.location='#{staging_workflow_path(@staging_workflow)}'"
    end
  end

  private

  def set_bootstrap_views
    prepend_view_path('app/views/webui2')
  end

  def set_staging_workflow
    @staging_workflow = ::Staging::Workflow.find_by(id: params[:id])
    return if @staging_workflow

    redirect_back(fallback_location: root_path)
    flash[:error] = "StagingWorkflow with id = #{params[:id]} doesn't exist"
    return
  end
end
