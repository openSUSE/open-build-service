class Staging::StagedRequestsController < ApplicationController
  before_action :require_login, except: [:index]
  before_action :set_staging_project
  before_action :set_staging_workflow, :set_project, :set_xml_hash, only: [:create, :destroy]

  def index
    @requests = @staging_project.staged_requests
  end

  def create
    authorize @staging_project, :update?

    result = ::Staging::StageRequests.new(
      request_numbers: request_numbers,
      staging_workflow: @staging_workflow,
      staging_project_name: @staging_project.name
    ).perform

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
    requests = @staging_project.staged_requests.where(number: request_numbers)
    package_names = requests.joins(:bs_request_actions).pluck('bs_request_actions.target_package')

    @staging_project.staged_requests.delete(requests)
    not_unassigned_requests = request_numbers - requests.pluck(:number).map(&:to_s)

    result = @staging_project.packages.where(name: package_names).destroy_all
    not_deleted_packages = package_names - result.pluck(:name)

    if not_unassigned_requests.empty? && not_deleted_packages.empty?
      render_ok
    else
      message = 'Error while unassigning requests: '
      message << "Requests with number #{not_unassigned_requests.to_sentence} not found. " unless not_unassigned_requests.empty?
      message << "Could not delete packages #{not_deleted_packages.to_sentence}." unless not_deleted_packages.empty?
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: message
      )
    end
  end

  private

  def set_xml_hash
    @xml_hash = (Xmlhash.parse(request.body.read) || {}).with_indifferent_access
  end

  def request_numbers
    [@xml_hash[:number]].flatten
  end

  def set_staging_project
    @staging_project = Staging::StagingProject.find_by!(name: params[:staging_project_name])
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
end
