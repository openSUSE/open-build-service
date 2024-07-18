class Staging::StagingProjectsController < Staging::StagingController
  include Staging::Errors

  before_action :set_project
  before_action :set_staging_workflow, only: :create
  before_action :set_options, only: %i[index show]
  before_action :set_staging_project, only: %i[show accept]

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
    result = ::Staging::StagingProjectCreator.new(request.body.read, @staging_workflow, User.session).call

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

    StagingProjectCopyJob.perform_later(params[:staging_workflow_project], params[:staging_project_name], params[:staging_project_copy_name], User.session.id)
    render_ok
  end

  def accept
    authorize @staging_project, :accept?

    if acceptable?(force: params[:force].present?)
      StagingProjectAcceptJob.perform_later(project_id: @staging_project.id, user_login: User.session.login)
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'staging_project_not_in_acceptable_state',
        message: "Staging Project is not acceptable: #{@acceptable_error}"
      )
    end
  end

  private

  def acceptable?(force: false)
    @acceptable_error = 'has reviews open' unless @staging_project.missing_reviews.empty?

    if force
      @acceptable_error = "is not in state #{StagingProject::FORCEABLE_STATES.to_sentence(last_word_connector: ' or ')}" unless @staging_project.overall_state.in?(StagingProject::FORCEABLE_STATES)
    else
      @acceptable_error = "#{@staging_project.overall_state} is not an acceptable state" unless @staging_project.overall_state == :acceptable
    end
    @acceptable_error.blank?
  end

  def set_options
    @options = {}
    %i[requests history status].each do |option|
      @options[option] = params[option].present?
    end
  end

  def set_staging_project
    raise StagingWorkflowNotFound, "Staging Workflow for project \"#{@project.name}\" does not exist." unless @project.staging

    included_associations = []
    included_associations << :staged_requests if @options && @options.key?(:requests)

    @staging_project = @project.staging.staging_projects.includes(included_associations)
                               .find_by(name: params[:staging_project_name])
    return if @staging_project

    raise StagingProjectNotFound, "Staging Project \"#{params[:staging_project_name]}\" does not exist."
  end
end
