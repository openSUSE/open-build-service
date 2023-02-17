# Contains the payload extracted from a SCM webhook and provides helper methods to know which webhook event we're dealing with
class SCMWebhook
  include ActiveModel::Model
  include SCMWebhookInstrumentation # for run_callbacks

  attr_accessor :payload

  validates_with SCMWebhookEventValidator

  ALLOWED_PULL_REQUEST_ACTIONS = ['closed', 'opened', 'reopened', 'synchronize', 'synchronized'].freeze
  ALLOWED_MERGE_REQUEST_ACTIONS = ['close', 'merge', 'open', 'reopen', 'update'].freeze

  def initialize(attributes = {})
    run_callbacks(:initialize) do
      super
      # To safely navigate the hash and compare keys
      @payload = attributes[:payload].deep_symbolize_keys
    end
  end

  def new_pull_request?
    (github_pull_request? && @payload[:action] == 'opened') ||
      (gitlab_merge_request? && @payload[:action] == 'open') ||
      (gitea_pull_request? && @payload[:action] == 'opened')
  end

  def updated_pull_request?
    (github_pull_request? && @payload[:action] == 'synchronize') ||
      (gitlab_merge_request? && @payload[:action] == 'update') ||
      (gitea_pull_request? && @payload[:action] == 'synchronized')
  end

  def closed_merged_pull_request?
    (github_pull_request? && @payload[:action] == 'closed') ||
      (gitlab_merge_request? && ['close', 'merge'].include?(@payload[:action])) ||
      (gitea_pull_request? && @payload[:action] == 'closed')
  end

  def reopened_pull_request?
    (github_pull_request? && @payload[:action] == 'reopened') ||
      (gitlab_merge_request? && @payload[:action] == 'reopen') ||
      (gitea_pull_request? && @payload[:action] == 'reopened')
  end

  def push_event?
    github_push_event? || gitlab_push_event? || gitea_push_event?
  end

  def tag_push_event?
    github_tag_push_event? || gitlab_tag_push_event? || gitea_tag_push_event?
  end

  def pull_request_event?
    github_pull_request? || gitlab_merge_request? || gitea_pull_request?
  end

  def ignored_pull_request_action?
    ignored_github_pull_request_action? || ignored_gitlab_merge_request_action? || ignored_gitea_pull_request_action?
  end

  def ping_event?
    github_ping? || gitea_ping?
  end

  def ignored_push_event?
    ignored_github_push_event? || ignored_gitlab_push_event?
  end

  private

  def github_push_event?
    @payload[:scm] == 'github' && @payload[:event] == 'push' && @payload.fetch(:ref, '').start_with?('refs/heads/')
  end

  def gitlab_push_event?
    @payload[:scm] == 'gitlab' && @payload[:event] == 'Push Hook'
  end

  def gitea_push_event?
    @payload[:scm] == 'gitea' && @payload[:event] == 'push' && @payload.fetch(:ref, '').start_with?('refs/heads/')
  end

  def github_tag_push_event?
    @payload[:scm] == 'github' && @payload[:event] == 'push' && @payload.fetch(:ref, '').starts_with?('refs/tags/')
  end

  def gitlab_tag_push_event?
    @payload[:scm] == 'gitlab' && @payload[:event] == 'Tag Push Hook'
  end

  def gitea_tag_push_event?
    @payload[:scm] == 'gitea' && @payload[:event] == 'push' && @payload.fetch(:ref, '').starts_with?('refs/tags/')
  end

  def github_pull_request?
    @payload[:scm] == 'github' && @payload[:event] == 'pull_request'
  end

  def gitlab_merge_request?
    @payload[:scm] == 'gitlab' && @payload[:event] == 'Merge Request Hook'
  end

  def gitea_pull_request?
    @payload[:scm] == 'gitea' && @payload[:event] == 'pull_request'
  end

  def github_ping?
    @payload[:scm] == 'github' && @payload[:event] == 'ping'
  end

  def gitea_ping?
    @payload[:scm] == 'gitea' && @payload[:event] == 'ping'
  end

  def ignored_github_pull_request_action?
    github_pull_request? && ALLOWED_PULL_REQUEST_ACTIONS.exclude?(@payload[:action])
  end

  def ignored_gitlab_merge_request_action?
    gitlab_merge_request? && ALLOWED_MERGE_REQUEST_ACTIONS.exclude?(@payload[:action])
  end

  def ignored_gitea_pull_request_action?
    gitea_pull_request? && ALLOWED_PULL_REQUEST_ACTIONS.exclude?(@payload[:action])
  end

  def ignored_github_push_event?
    github_push_event? && @payload[:deleted]
  end

  def ignored_gitlab_push_event?
    # In Push Hook events to delete a branch, the after field is '0000000000000000000000000000000000000000'
    gitlab_push_event? && @payload[:commit_sha].match?(/\A0+\z/)
  end
end
