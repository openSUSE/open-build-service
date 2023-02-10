# rubocop:disable Metrics/ClassLength
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

  PERMITTED_OPTIONS = [
    # Permitted keys for GitHub
    :api_endpoint, :target_repository_full_name, :commit_sha,
    # Permitted keys for GitLab
    :endpoint, :project_id, :commit_sha,
    # both GitHub and GitLab
    :state, :status_options
  ].freeze

  validates :response_url, length: { maximum: 255 }
  validates :request_headers, :status, presence: true

  belongs_to :token, class_name: 'Token::Workflow', optional: true
  has_many :artifacts, class_name: 'WorkflowArtifactsPerStep', dependent: :destroy
  has_many :scm_status_reports, class_name: 'SCMStatusReport', dependent: :destroy
  has_many :event_subscriptions, dependent: :destroy

  paginates_per 20

  enum status: {
    running: 0,
    success: 1,
    fail: 2
  }

  # Marks the workflow run as failed and records the relevant debug information in response_body
  def update_as_failed(message)
    update(response_body: message, status: 'fail')
  end

  # Stores debug info to help figure out what went wrong when trying to save a Status in the SCM.
  # Marks the workflow run as failed also.
  def save_scm_report_failure(message, options)
    update(status: 'fail') # set WorkflowRun status
    scm_status_reports.create(response_body: message,
                              request_parameters: JSON.generate(options.slice(*PERMITTED_OPTIONS)),
                              status: 'fail') # set SCMStatusReport status
  end

  # Stores info from a succesful SCM status report. The default value for 'status' is 'success'.
  def save_scm_report_success(options)
    scm_status_reports.create(request_parameters: JSON.generate(options.slice(*PERMITTED_OPTIONS)))
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
    payload.dig('repository', 'full_name') || # For GitHub and Gitea on pull_request and push events
      payload.dig('project', 'path_with_namespace') # For GitLab on merge request and push events
  end

  def repository_url
    payload.dig('repository', 'html_url') || # For GitHub and Gitea on pull_request and push events
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

  def generic_event_type
    # We only have filters for push, tag_push, and pull_request
    if hook_event == 'Push Hook' || payload.fetch('ref', '').match('refs/heads')
      'push'
    elsif hook_event == 'Tag Push Hook' || payload.fetch('ref', '').match('refs/tag')
      'tag_push'
    elsif hook_event.in?(['pull_request', 'Merge Request Hook'])
      'pull_request'
    end
  end

  # FIXME: This `if github do this and if gitlab do that` is scattered around
  # the code regarding workflow runs. It is asking for a refactor putting
  # together all the behaviour regarding GitHub and all the behaviour regarding
  # GitLab.
  def scm_vendor
    if parsed_request_headers['HTTP_X_GITEA_EVENT']
      :gitea
    elsif parsed_request_headers['HTTP_X_GITHUB_EVENT']
      :github
    elsif parsed_request_headers['HTTP_X_GITLAB_EVENT']
      :gitlab
    else
      :unknown
    end
  end

  def last_response_body
    scm_status_reports.last&.response_body
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
      SCMWebhook::ALLOWED_PULL_REQUEST_ACTIONS.include?(payload['action'])
  end

  def merge_request_with_allowed_action
    hook_event == 'Merge Request Hook' &&
      SCMWebhook::ALLOWED_MERGE_REQUEST_ACTIONS.include?(payload.dig('object_attributes', 'action'))
  end
end
# rubocop:enable Metrics/ClassLength

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
