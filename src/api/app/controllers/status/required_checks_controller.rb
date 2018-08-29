class Status::RequiredChecksController < ApplicationController
  #### Includes and extends

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :set_checkable, only: [:index, :create, :destroy]
  before_action :set_required_check, only: [:destroy]
  skip_before_action :require_login, only: [:index]
  # Pundit authorization policies control
  after_action :verify_authorized

  #### CRUD actions

  # GET /projects/:project_name/repositories/:repository_name/required_checks
  def index
    authorize @checkable
    @required_checks = @checkable.required_checks
  end

  # POST /projects/:project_name/repositories/:repository_name/required_checks
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

  # DELETE /projects/:project_name/repositories/:repository_name/required_checks/:name
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

  def set_checkable
    @project = Project.get_by_name(params[:project_name])
    if params[:repository_name]
      @checkable = @project.repositories.find_by(name: params[:repository_name])
      return if @checkable

      render_error(
        status: 404,
        errorcode: 'not_found',
        message: "Unable to find repository with name '#{params[:project_name]}/#{params[:repository_name]}'"
      )
    else
      render_error(
        status: 404,
        errorcode: 'not_found',
        message: 'No repository name specified.'
      )
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
