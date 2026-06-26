class Status::RequiredChecksController < ApplicationController
  #### Includes and extends

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :set_project, only: %i[index create destroy]
  before_action :set_checkable, only: %i[index create destroy]
  skip_before_action :require_login, only: [:index]
  # Pundit authorization policies control
  after_action :verify_authorized

  #### CRUD actions

  # GET /status_reports/projects/:project_name/required_checks
  # GET /status_reports/repositories/:project_name/:repository_name/required_checks
  # GET /status_reports/built_repositories/:project_name/:repository_name/:architecture_name/required_checks
  def index
    authorize @checkable
    @required_checks = @checkable.required_checks
  end

  # POST /status_reports/projects/:project_name/required_checks
  # POST /status_reports/repositories/:project_name/:repository_name/required_checks
  # POST /status_reports/built_repositories/:project_name/:repository_name/:architecture_name/required_checks
  def create
    authorize @checkable
    @required_checks = @checkable.required_checks |= names

    if @checkable.save
      render action: :index
    else
      render_error(
        status: 422,
        errorcode: 'invalid_required_check',
        message: "Could not save required check: #{@checkable.errors.full_messages.to_sentence}"
      )
    end
  end

  # DELETE /status_reports/projects/:project_name/required_checks/:name
  # DELETE /status_reports/repositories/:project_name/:repository_name/required_checks/:name
  # DELETE /status_reports/built_repositories/:project_name/:repository_name/:architecture_name/required_checks/:name
  def destroy
    authorize @checkable
    set_required_check
    @checkable.required_checks.delete(@required_check)

    if @checkable.save
      render_ok
    else
      render_error(
        status: 422,
        errorcode: 'invalid_required_check',
        message: "Could not delete required check: #{@checkable.errors.full_messages.to_sentence}"
      )
    end
  end

  #### Non CRUD actions

  #### Non actions methods
  # Use hide_action if they are not private

  private

  def set_project
    @project = Project.get_by_name(params[:project_name])

    return if @project

    render_error status: 404, message: "Project '#{params[:project_name]}' not found."
  end

  def set_checkable
    @checkable = checkable
  end

  def checkable
    return @project unless params[:repository_name]

    repo = @project.repositories.find_by(name: params[:repository_name])
    raise NotFoundError, "Couldn't find repository '#{params[:repository_name]}'" if repo.nil?

    return repo unless params[:architecture_name]

    architecture = Architecture.find_by(name: params[:architecture_name])
    raise NotFoundError, "Couldn't find architecture '#{params[:architecture_name]}'" if architecture.nil?

    repo_architecture = repo.repository_architectures.find_by(architecture: architecture)
    raise NotFoundError, "Couldn't find architecture '#{architecture}'" if repo_architecture.nil?

    repo_architecture
  end

  def set_required_check
    @required_check = params[:name] if @checkable.required_checks.include?(params[:name])

    raise NotFoundError, "Unable to find required check with name '#{params[:name]}'" if @required_check.nil?
  end

  def names
    result = (Xmlhash.parse(request.body.read) || {}).with_indifferent_access
    [result[:name]].flatten.compact_blank
  end
end
