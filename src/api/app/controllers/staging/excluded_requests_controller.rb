class Staging::ExcludedRequestsController < ApplicationController
  before_action :require_login, except: [:index]
  before_action :set_project
  before_action :set_staging_workflow, :set_requests_xml_hash

  def index
    @request_exclusions = @staging_workflow.request_exclusions
  end

  def create
    authorize @staging_workflow, policy_class: Staging::RequestExclusionPolicy

    result = ::Staging::RequestExcluder.new(requests_xml_hash: @requests_xml_hash, staging_workflow: @staging_workflow).create

    if result.valid?
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Excluding requests for #{@staging_workflow} failed: #{result.errors.join(' ')}"
      )
    end
  end

  def destroy
    authorize @staging_workflow, policy_class: Staging::RequestExclusionPolicy

    result = ::Staging::RequestExcluder.new(requests_xml_hash: @requests_xml_hash, staging_workflow: @staging_workflow).destroy

    if result.valid?
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Error while unexcluding requests: #{result.errors.join(' ')}"
      )
    end
  end

  private

  def set_requests_xml_hash
    @requests_xml_hash = (Xmlhash.parse(request.body.read) || {}).with_indifferent_access
  end

  def set_project
    @project = Project.get_by_name(params[:staging_main_project_name])
  end

  def set_staging_workflow
    @staging_workflow = @project.staging
    return if @staging_workflow

    raise InvalidParameterError, "Project #{params[:staging_main_project_name]} doesn't have an asociated Staging Workflow"
  end
end
