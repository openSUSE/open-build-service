class WorkflowRunDetailComponent < ApplicationComponent
  attr_reader :id, :workflow_run, :request_headers, :pretty_request_payload,
              :response_url, :response_body, :artifacts,
              :scm_vendor, :status_reports

  def initialize(workflow_run:)
    super
    @id = workflow_run.id
    @workflow_run = workflow_run
    @request_headers = workflow_run.request_headers
    @pretty_request_payload = parse_payload(workflow_run)
    @response_url = workflow_run.response_url
    @response_body = workflow_run.response_body
    @artifacts = workflow_run.artifacts # collection of WorkflowArtifactsPerStep
    @scm_vendor = workflow_run.scm_vendor.to_s.humanize
    @status_reports = workflow_run.scm_status_reports
  end

  private

  def parse_payload(workflow_run)
    JSON.pretty_generate(JSON.parse(workflow_run.request_payload))
  rescue JSON::ParserError
    workflow_run.request_payload
  end

  # Old workflow run entries didn't store the configuration-related information
  def workflow_configuration_data
    configuration_source = [workflow_run.workflow_configuration_url,
                            workflow_run.workflow_configuration_path].filter_map(&:presence).first

    return content_tag(:p, 'This information is not available.') unless configuration_source

    content_tag(:h5, "Workflow Configuration File #{workflow_run.workflow_configuration_url.present? ? 'URL' : 'Path'}").concat(
      content_tag(:pre,
                  configuration_source,
                  class: 'border p-2')
    )
  end
end
