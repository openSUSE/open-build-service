class WorkflowRun < ApplicationRecord
  SOURCE_NAME_PAYLOAD_MAPPING = {
    'pull_request' => ['pull_request', 'number'],
    'Merge Request Hook' => ['object_attributes', 'iid'],
    'push' => ['head_commit', 'id'],
    'Push Hook' => ['commits', 0, 'id']
  }.freeze

  SOURCE_URL_PAYLOAD_MAPPING = {
    'pull_request' => ['pull_request', 'html_url'],
    'Merge Request Hook' => ['object_attributes', 'url'],
    'push' => ['head_commit', 'url'],
    'Push Hook' => ['commits', 0, 'url']
  }.freeze

  validates :response_url, length: { maximum: 255 }
  validates :request_headers, :status, presence: true

  belongs_to :token, class_name: 'Token::Workflow', optional: true
  has_many :artifacts, class_name: 'WorkflowArtifactsPerStep', dependent: :destroy

  paginates_per 20

  enum status: {
    running: 0,
    success: 1,
    fail: 2
  }

  def update_to_fail(message)
    update(response_body: message, status: 'fail')
  end

  def payload
    JSON.parse(request_payload)
  rescue JSON::ParserError
    { payload: 'unparseable' }
  end

  def hook_event
    parsed_request_headers['HTTP_X_GITHUB_EVENT'] ||
      parsed_request_headers['HTTP_X_GITLAB_EVENT']
  end

  def hook_action
    return payload['action'] if pull_request_with_allowed_action
    return payload.dig('object_attributes', 'action') if merge_request_with_allowed_action
  end

  def repository_name
    payload.dig('repository', 'full_name') || # For GitHub on pull_request and push events
      payload.dig('project', 'path_with_namespace') # For GitLab on merge request and push events
  end

  def repository_url
    payload.dig('repository', 'html_url') || # For GitHub on pull_request and push events
      payload.dig('project', 'web_url') # For GitLab on merge request and push events
  end

  def event_source_name
    path = SOURCE_NAME_PAYLOAD_MAPPING[hook_event]
    payload.dig(*path) if path
  end

  def event_source_url
    mapped_source_url = SOURCE_URL_PAYLOAD_MAPPING[hook_event]
    payload.dig(*mapped_source_url) if mapped_source_url
  end

  private

  def parsed_request_headers
    request_headers.split("\n").each_with_object({}) do |h, headers|
      k, v = h.split(':')
      headers[k] = v.strip
    end
  end

  def pull_request_with_allowed_action
    hook_event == 'pull_request' &&
      ScmWebhookEventValidator::ALLOWED_PULL_REQUEST_ACTIONS.include?(payload['action'])
  end

  def merge_request_with_allowed_action
    hook_event == 'Merge Request Hook' &&
      ScmWebhookEventValidator::ALLOWED_MERGE_REQUEST_ACTIONS.include?(payload.dig('object_attributes', 'action'))
  end
end

# == Schema Information
#
# Table name: workflow_runs
#
#  id              :integer          not null, primary key
#  request_headers :text(65535)      not null
#  request_payload :text(4294967295) not null
#  response_body   :text(65535)
#  response_url    :string(255)
#  status          :integer          default("running"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  token_id        :integer          not null, indexed
#
# Indexes
#
#  index_workflow_runs_on_token_id  (token_id)
#
