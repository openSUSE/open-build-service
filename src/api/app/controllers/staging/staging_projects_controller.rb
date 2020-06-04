class Staging::StagingProjectsController < Staging::StagingController
  include Staging::Errors

  before_action :require_login, except: [:index, :show]
  before_action :set_project
  before_action :set_staging_workflow, only: :create
  before_action :set_options, only: [:index, :show]
  before_action :set_staging_project, only: [:show, :accept]

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

  def show; end

  def create
    authorize @staging_workflow, policy_class: Staging::StagedRequestPolicy
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
    authorize @staging_project, :accept?
    authorize @project, :update?

    # check general state
    raise StagingProjectNotAcceptable, 'Staging project is not in state acceptable.' unless can_accept?

    # Disabling build for all repositories and architectures.
    build_flag = @staging_project.flags.find_or_initialize_by(flag: 'build', repo: nil, architecture_id: nil)
    build_flag.update(status: 'disable')

    # Remove all the build flags enabled by the user.
    @staging_project.flags.where(flag: 'build', status: 'enable').destroy_all
    @staging_project.store

    StagingProjectAcceptJob.perform_later(project_id: @staging_project.id, user_login: User.session!.login)
    render_ok
  end

  private

  def can_accept?
    return true if @staging_project.overall_state == :acceptable

    params[:force].present? && @staging_project.force_acceptable?
  end

  def set_options
    @options = {}
    [:requests, :history, :status].each do |option|
      @options[option] = params[option].present?
    end
  end

  def set_staging_project
    raise StagingWorkflowNotFound, "Staging Workflow for project \"#{@project.name}\" does not exist." unless @project.staging

    @staging_project = @project.staging.staging_projects.find_by(name: params[:staging_project_name])
    return if @staging_project

    raise StagingProjectNotFound, "Staging Project \"#{params[:staging_project_name]}\" does not exist."
  end
end
