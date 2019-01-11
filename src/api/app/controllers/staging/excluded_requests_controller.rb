class Staging::ExcludedRequestsController < ApplicationController
  before_action :require_login
  before_action :set_project
  before_action :set_staging_workflow, :set_requests_xml_hash

  def create
    authorize @staging_workflow, policy_class: Staging::RequestExclusionPolicy

    @result = ::Staging::RequestExclusion.create(requests_to_be_excluded)

    if errors?
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Excluding requests for #{@staging_workflow} failed: #{errors_list.join('. ')}."
      )
    else
      render_ok
    end
  end

  def destroy
    authorize @staging_workflow, policy_class: Staging::RequestExclusionPolicy

    request_exclusions = @staging_workflow.request_exclusions.where(number: request_numbers).destroy_all
    not_found_requests = request_numbers - request_exclusions.pluck(:number).map(&:to_s)

    if not_found_requests.empty?
      render_ok
    else
      message = 'Error while unexcluding requests: '
      message << "Requests with number #{not_found_requests.to_sentence} couldn't be unexcluded. " unless not_found_requests.empty?
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: message
      )
    end
  end

  private

  def set_requests_xml_hash
    @requests_xml_hash = (Xmlhash.parse(request.body.read) || {}).with_indifferent_access
  end

  def xml_hash_requests
    [@requests_xml_hash[:request]].flatten
  end

  def request_numbers
    [@requests_xml_hash[:number]].flatten
  end

  def requests_to_be_excluded
    xml_hash_requests.map do |request|
      bs_request = @staging_workflow.unassigned_requests.find_by_number(request[:number])
      { bs_request: bs_request, number: bs_request.try(:number), description: request[:description], staging_workflow: @staging_workflow }
    end
  end

  def errors?
    errors_list.present?
  end

  def errors_list
    return @errors if @errors
    @errors = []
    @result.each do |request|
      @errors << "Request #{request.bs_request_id}: #{request.errors.full_messages.to_sentence}" if request.errors.any?
    end

    @errors
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
