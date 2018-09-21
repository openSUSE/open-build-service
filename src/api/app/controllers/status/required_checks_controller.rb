class Status::RequiredChecksController < ApplicationController
  #### Includes and extends

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :set_project, only: [:index, :create, :destroy]
  before_action :set_checkable, only: [:index, :create, :destroy]
  before_action :set_required_check, only: [:destroy]
  skip_before_action :require_login, only: [:index]
  # Pundit authorization policies control
  after_action :verify_authorized

  #### CRUD actions

  # GET /status_reports/projects/:project_name/required_checks
  # GET /status_reports/repositories/:project_name/:repository_name/required_checks
  def index
    authorize @checkable
    @required_checks = @checkable.required_checks
  end

  # POST /status_reports/projects/:project_name/required_checks
  # POST /status_reports/repositories/:project_name/:repository_name/required_checks
  def create
    authorize @checkable
    @checkable.required_checks = @checkable.required_checks | names
    @required_checks = @checkable.required_checks

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
  def destroy
    authorize @checkable
    @checkable.required_checks -= [params[:name]]

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
    render_error(
      status: 404,
      errorcode: 'not_found',
      message: "Project '#{params[:project_name]}' not found."
    )
  end

  def set_checkable
    if params[:repository_name]
      @checkable = @project.repositories.find_by(name: params[:repository_name])
      return if @checkable

      render_error(
        status: 404,
        errorcode: 'not_found',
        message: "Repository '#{params[:repository_name]}/#{params[:project_name]}' not found."
      )
    else
      @checkable = @project
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_required_check
    @required_check = @checkable.required_checks.find(params[:id])
    return if @required_check

    render_error(
      status: 404,
      errorcode: 'not_found',
      message: "Unable to find required check with id '#{params[:id]}'"
    )
  end

  def names
    result = (Xmlhash.parse(request.body.read) || {}).with_indifferent_access
    [result[:name]].flatten.reject(&:blank?)
  end
end
