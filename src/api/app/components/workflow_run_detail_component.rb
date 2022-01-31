class WorkflowRunDetailComponent < ApplicationComponent
  attr_reader :id, :request_headers, :pretty_request_payload,
              :response_url, :response_body, :artifacts

  def initialize(workflow_run:)
    super
    @id = workflow_run.id
    @request_headers = workflow_run.request_headers
    @pretty_request_payload = parse_payload(workflow_run)
    @response_url = workflow_run.response_url
    @response_body = workflow_run.response_body
    @artifacts = workflow_run.artifacts # collection of WorkflowArtifactsPerStep
  end

  private

  def parse_payload(workflow_run)
    JSON.pretty_generate(JSON.parse(workflow_run.request_payload))
  rescue JSON::ParserError
    workflow_run.request_payload
  end
end
