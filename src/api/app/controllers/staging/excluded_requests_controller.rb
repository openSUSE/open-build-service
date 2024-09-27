class Staging::ExcludedRequestsController < Staging::StagingController
  before_action :set_project
  before_action :set_staging_workflow
  before_action :set_xml_hash, except: :index

  def index
    @request_exclusions = @staging_workflow.request_exclusions
  end

  def create
    authorize @staging_workflow, policy_class: Staging::RequestExclusionPolicy

    result = ::Staging::RequestExcluder.new(requests_xml_hash: @parsed_xml, staging_workflow: @staging_workflow).create

    if result.valid?
      render_ok
    else
      render_error(
        status: 400,
        errorcode: 'invalid_request',
        message: "Excluding requests for #{@staging_workflow.project} failed: #{result.errors.join(' ')}"
      )
    end
  end

  def destroy
    authorize @staging_workflow, policy_class: Staging::RequestExclusionPolicy

    result = ::Staging::RequestExcluder.new(requests_xml_hash: @parsed_xml, staging_workflow: @staging_workflow).destroy

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
end
