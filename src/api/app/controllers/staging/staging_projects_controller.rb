class Staging::StagingProjectsController < Staging::StagingController
  before_action :require_login, except: [:index, :show, :detail]
  before_action :set_project
  before_action :set_staging_workflow, only: :create

  validate_action create: { method: :post, request: :staging_project }

  def index
    if @project.staging
      @staging_workflow = @project.staging
      @staging_projects = @staging_workflow.staging_projects
    else
      render_error(
        status: 404,
        errorcode: 'project_has_no_staging_workflow',
        message: "No staging workflow for project '#{@project}'"
      )
    end
  end

  def show
    @staging_project = @project.staging.staging_projects.find_by!(name: params[:staging_project_name])
  end

  def detail
    @staging_project = @project.staging.staging_projects.find_by!(name: params[:staging_project_name])
  end

  def create
    authorize @staging_workflow
    result = ::Staging::StagingProjectCreator.new(request.body.read, @staging_workflow, User.session!).call

    if result.valid?
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Staging Projects for #{@project} failed: #{result.errors.join(' ')}"
      )
    end
  end

  def copy
    authorize @project.staging

    StagingProjectCopyJob.perform_later(params[:staging_workflow_project], params[:staging_project_name], params[:staging_project_copy_name], User.session!.id)
    render_ok
  end

  def accept
    staging_project = Project.find_by!(name: params[:staging_project_name])
    authorize staging_project, :update?

    if staging_project.overall_state != :acceptable
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: 'Staging project is not in state acceptable.'
      )
      return
    end
    StagingProjectAcceptJob.perform_later(project_id: staging_project.id, user_login: User.session!.login)
    render_ok
  end
end
