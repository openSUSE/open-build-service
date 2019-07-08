class Staging::StagedRequestsController < ApplicationController
  before_action :require_login, except: [:index]
  before_action :set_staging_project
  before_action :set_staging_workflow, :set_project, :check_overall_state, only: [:create, :destroy]

  validate_action create: { method: :post, request: :number, response: :number }, destroy: { method: :delete, request: :number, response: :number }

  def index
    @requests = @staging_project.staged_requests
  end

  def create
    authorize @staging_project, :update?

    result = ::Staging::StageRequests.new(
      request_numbers: request_numbers,
      staging_workflow: @staging_workflow,
      staging_project: @staging_project,
      user_login: User.session!.login
    ).create

    if result.valid?
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Assigning requests to #{@staging_project} failed: #{result.errors.to_sentence}."
      )
    end
  end

  def destroy
    authorize @staging_project, :update?

    result = ::Staging::StageRequests.new(
      request_numbers: request_numbers,
      staging_workflow: @staging_workflow,
      staging_project: @staging_project,
      user_login: User.session!.login
    ).destroy

    if result.valid?
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Error while unassigning requests: #{result.errors.to_sentence}"
      )
    end
  end

  private

  def request_numbers
    xml_hash.elements('number')
  end

  def xml_hash
    Xmlhash.parse(request.body.read) || {}
  end

  def set_staging_project
    @staging_project = Project.get_by_name(params[:staging_project_name])
  end

  def set_staging_workflow
    @staging_workflow = @staging_project.staging_workflow
    return if @staging_workflow
    render_error(
      status: 422,
      errorcode: 'invalid_request',
      message: "#{@staging_project} is not a valid staging project, can't assign requests to it."
    )
  end

  def set_project
    @project = @staging_workflow.project
  end

  def check_overall_state
    return if @staging_project.overall_state != :accepting
    render_error(
      status: 424,
      errorcode: 'staging_project_not_in_acceptable_state',
      message: "Can't change staged requests: Project '#{@project}' is being accepted."
    )
  end
end
