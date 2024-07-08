class Staging::StagedRequestsController < Staging::StagingController
  before_action :set_project
  before_action :set_staging_workflow
  before_action :set_staging_project, except: :destroy
  before_action :check_overall_state, only: :create
  before_action :set_xml_hash, :set_request_numbers, only: %i[create destroy]

  validate_action create: { method: :post, request: :number, response: :number }, destroy: { method: :delete, request: :number, response: :number }

  def index
    @requests = @staging_project.staged_requests
  end

  def create
    authorize @staging_workflow, policy_class: Staging::StagedRequestPolicy

    if params[:remove_exclusion]
      ::Staging::RequestExcluder
        .new(requests_xml_hash: @parsed_xml,
             staging_workflow: @staging_workflow)
        .destroy!
    end

    ::Staging::StagedRequests.new(
      request_numbers: @request_numbers,
      staging_workflow: @staging_workflow,
      staging_project: @staging_project,
      user_login: User.session.login
    ).create!

    render_ok
  end

  def destroy
    authorize @staging_workflow, policy_class: Staging::StagedRequestPolicy

    result = ::Staging::StagedRequests.new(
      request_numbers: @request_numbers,
      staging_workflow: @staging_workflow,
      user_login: User.session.login
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

  def set_request_numbers
    @request_numbers = [@parsed_xml[:request]].flatten.map { |request| request[:id].to_i }
    return if @request_numbers.present?

    render_error(
      status: 400,
      errorcode: 'invalid_request',
      message: 'Error while parsing the numbers of the requests'
    )
  end

  def set_staging_project
    @staging_project = @staging_workflow.staging_projects.find_by(name: params[:staging_project_name])
    return if @staging_project

    render_error status: 404, message: "Staging Project '#{params[:staging_project_name]}' not found in Staging: '#{@staging_workflow.project}'"
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
