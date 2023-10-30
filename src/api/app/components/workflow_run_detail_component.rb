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
    @scm_vendor = workflow_run.scm_vendor.humanize
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
    return content_tag(:p, 'This information is not available.') unless workflow_run.configuration_source

    output = content_tag(:h5, "Workflow Configuration File #{workflow_run.workflow_configuration_url.present? ? 'URL' : 'Path'}").concat(
      content_tag(:pre, workflow_run.configuration_source, class: 'border p-2')
    )

    if workflow_run.workflow_configuration
      output.concat(
        content_tag(:h5, 'Workflow Configuration').concat(
          content_tag(:pre, workflow_run.workflow_configuration, class: 'border p-2')
        )
      )
    end

    output
  end
end
