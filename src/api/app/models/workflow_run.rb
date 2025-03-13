# rubocop:disable Metrics/ClassLength

class WorkflowRun < ApplicationRecord
  include WorkflowRunGitlabPayload
  include WorkflowRunGithubPayload
  include WorkflowRunGiteaPayload
  include WorkflowRunPayload

  SOURCE_URL_PAYLOAD_MAPPING = {
    'pull_request' => %w[pull_request html_url],
    'Merge Request Hook' => %w[object_attributes url],
    'push' => %w[head_commit url],
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

  ALL_POSSIBLE_REQUEST_ACTIONS = (['all'] + ALLOWED_GITHUB_PULL_REQUEST_ACTIONS + ALLOWED_GITLAB_PULL_REQUEST_ACTIONS + ALLOWED_GITEA_PULL_REQUEST_ACTIONS).uniq

  validates :scm_vendor, :response_url,
            :workflow_configuration_path, :workflow_configuration_url,
            :hook_event, :hook_action, :generic_event_type,
            :repository_name, :repository_owner, :event_source_name, length: { maximum: 255 }
  validates :request_headers, :status, :scm_vendor, :hook_event, :request_payload, presence: true
  validates :workflow_configuration, length: { maximum: 65_535 }
  validates :scm_vendor, inclusion: { in: %w[github gitlab gitea], message: "unsupported '%{value}'" }, if: -> { scm_vendor.present? }
  validates :hook_event, inclusion: { in: ALLOWED_GITHUB_EVENTS, allow_nil: true, message: "unsupported '%{value}'" }, if: -> { scm_vendor == 'github' }
  validates :hook_event, inclusion: { in: ALLOWED_GITLAB_EVENTS, allow_nil: true, message: "unsupported '%{value}'" }, if: -> { scm_vendor == 'gitlab' }
  validates :hook_event, inclusion: { in: ALLOWED_GITEA_EVENTS, allow_nil: true, message: "unsupported '%{value}'" }, if: -> { scm_vendor == 'gitea' }
  validates :hook_action, inclusion: { in: ALLOWED_GITHUB_PULL_REQUEST_ACTIONS, allow_nil: true, message: "unsupported '%{value}'" }, if: -> { scm_vendor == 'github' && hook_event == 'pull_request' }
  validates :hook_action, inclusion: { in: ALLOWED_GITEA_PULL_REQUEST_ACTIONS, allow_nil: true, message: "unsupported '%{value}'" }, if: -> { scm_vendor == 'gitea' && hook_event == 'pull_request' }
  validates :hook_action, inclusion: { in: ALLOWED_GITLAB_PULL_REQUEST_ACTIONS, allow_nil: true, message: "unsupported '%{value}'" }, if: -> { scm_vendor == 'gitlab' && hook_event == 'Merge Request Hook' }
  validate :validate_payload_is_json

  belongs_to :token, class_name: 'Token::Workflow', optional: true
  has_many :artifacts, class_name: 'WorkflowArtifactsPerStep', dependent: :destroy
  has_many :scm_status_reports, class_name: 'SCMStatusReport', dependent: :destroy
  has_many :event_subscriptions, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :delete_all

  before_validation(on: :create) do
    set_attributes_from_payload
  end
  after_save :create_event, if: :status_changed_to_fail?

  scope :pull_request, -> { where(generic_event_type: 'pull_request') }
  scope :push, -> { where(generic_event_type: 'push') }
  scope :tag_push, -> { where(generic_event_type: 'tag_push') }

  scope :with_statuses, ->(statuses) { where(status: statuses) }
  scope :with_types, ->(types) { where(generic_event_type: types) }
  scope :with_actions, ->(actions) { where(hook_action: actions) }
  scope :with_event_source_name, ->(source_name) { where(event_source_name: source_name) }

  paginates_per 20

  enum :status, {
    running: 0,
    success: 1,
    fail: 2
  }

  # Marks the workflow run as failed and records the relevant debug information in response_body
  def update_as_failed(message)
    update(response_body: message, status: 'fail')

    #
    # Circuit breaker for authorization problems
    #
    #   If message is one of these strings, we disable the token:
    #
    # "Failed to report back to GitLab: Unauthorized request. Please check your credentials again."
    # "Failed to report back to GitLab: Request forbidden."
    # "Failed to report back to GitHub: Unauthorized request. Please check your credentials again."
    # "Failed to report back to GitHub: Request is forbidden."

    token.update(enabled: false) if message.include?('Unauthorized request') || /Request (is )?forbidden/.match?(message)
  end

  # Stores debug info to help figure out what went wrong when trying to save a Status in the SCM.
  # Marks the workflow run as failed also.
  def save_scm_report_failure(message, options)
    update_as_failed(message)
    scm_status_reports.create(response_body: message,
                              request_parameters: JSON.generate(options.slice(*PERMITTED_OPTIONS)),
                              status: 'fail') # set SCMStatusReport status
  end

  # Stores info from a succesful SCM status report. The default value for 'status' is 'success'.
  def save_scm_report_success(options)
    scm_status_reports.create(request_parameters: JSON.generate(options.slice(*PERMITTED_OPTIONS)))
  end

  def payload
    JSON.parse(request_payload.presence || {}).with_indifferent_access
  rescue JSON::ParserError
    { payload: 'unparseable' }.with_indifferent_access
  end

  def repository_full_name
    return unless repository_owner && repository_name

    "#{repository_owner}/#{repository_name}"
  end

  def repository_url
    payload.dig('repository', 'html_url') || # For GitHub and Gitea on pull_request and push events
      payload.dig('project', 'web_url') # For GitLab on merge request and push events
  end

  def event_source_url
    mapped_source_url = SOURCE_URL_PAYLOAD_MAPPING[hook_event]
    payload.dig(*mapped_source_url) if mapped_source_url
  end

  def event_source_message
    case generic_event_type
    when 'pull_request'
      pull_request_message
    when generic_event_type == 'push'
      push_message
    when generic_event_type == 'tag_push'
      tag_push_message
    end
  end

  def last_response_body
    scm_status_reports.last&.response_body
  end

  def configuration_source
    [workflow_configuration_url, workflow_configuration_path].filter_map(&:presence).first
  end

  def formatted_event_source_name
    case hook_event
    when 'pull_request', 'Merge Request Hook'
      "##{event_source_name}"
    else
      event_source_name
    end
  end

  # Examples of summary:
  #   Pull request #234, opened
  #   Merge request hook #234, open
  #   Push 0940857924387654354986745938675645365436
  #   Tag push hook Unknown source
  def summary
    str = "#{hook_event&.humanize || 'unknown'} #{formatted_event_source_name}"
    str += ", #{hook_action.humanize.downcase}" if hook_action.present?
    str
  end

  private

  def validate_payload_is_json
    JSON.parse(request_payload)
  rescue JSON::ParserError
    errors.add(:request_payload, 'can not be parsed as JSON')
  end

  def set_attributes_from_payload
    self.hook_action ||= payload_hook_action
    self.event_source_name ||= payload_event_source_name
    self.repository_name ||= payload_repository_name
    self.repository_owner ||= payload_repository_owner
    self.generic_event_type ||= payload_generic_event_type
  end

  def event_parameters
    { id: id, token_id: token_id, hook_event: hook_event&.humanize || 'unknown', summary: summary, repository_full_name: repository_full_name }
  end

  def create_event
    Event::WorkflowRunFail.create(event_parameters)
  end

  def status_changed_to_fail?
    saved_change_to_status? && status == 'fail'
  end

  def pull_request_message
    case scm_vendor
    when 'github', 'gitea'
      title = payload.dig('pull_request', 'title')
      body = payload.dig('pull_request', 'body')
      "#{title}\n#{body}"
    when 'gitlab'
      title = payload.dig('object_attributes', 'title')
      body = payload.dig('object_attributes', 'description')
      "#{title}\n#{body}"
    end
  end

  def push_message
    case scm_vendor
    when 'github', 'gitea'
      payload.dig('head_commit', 'message')
    when 'gitlab'
      payload.dig('commits', 0, 'message')
    end
  end

  # FIXME: How to get the real commit message for tag_push?
  def tag_push_message
    "Tag #{payload['ref']} got pushed"
  end
end

# == Schema Information
#
# Table name: workflow_runs
#
#  id                          :integer          not null, primary key
#  event_source_name           :string(255)
#  generic_event_type          :string(255)
#  hook_action                 :string(255)
#  hook_event                  :string(255)
#  repository_name             :string(255)
#  repository_owner            :string(255)
#  request_headers             :text(65535)      not null
#  request_payload             :text(4294967295) not null
#  response_body               :text(65535)
#  response_url                :string(255)
#  scm_vendor                  :string(255)
#  status                      :integer          default("running"), not null
#  workflow_configuration      :text(65535)
#  workflow_configuration_path :string(255)
#  workflow_configuration_url  :string(255)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  token_id                    :integer          not null, indexed
#
# Indexes
#
#  index_workflow_runs_on_token_id  (token_id)
#
# rubocop:enable Metrics/ClassLength
