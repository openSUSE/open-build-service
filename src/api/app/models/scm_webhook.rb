# Contains the payload extracted from a SCM webhook and provides helper methods to know which webhook event we're dealing with
class ScmWebhook
  include ActiveModel::Model
  include ScmWebhookInstrumentation # for run_callbacks

  attr_accessor :payload

  validates_with ScmWebhookEventValidator

  IGNORED_PULL_REQUEST_ACTIONS = ['assigned', 'auto_merge_disabled', 'auto_merge_enabled', 'converted_to_draft',
                                  'edited', 'labeled', 'locked', 'ready_for_review', 'review_request_removed',
                                  'review_requested', 'unassigned', 'unlabeled', 'unlocked'].freeze
  IGNORED_MERGE_REQUEST_ACTIONS = ['approved', 'unapproved'].freeze
  ALLOWED_PULL_REQUEST_ACTIONS = ['closed', 'opened', 'reopened', 'synchronize'].freeze
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
      (gitlab_merge_request? && @payload[:action] == 'open')
  end

  def updated_pull_request?
    (github_pull_request? && @payload[:action] == 'synchronize') ||
      (gitlab_merge_request? && @payload[:action] == 'update')
  end

  def closed_merged_pull_request?
    (github_pull_request? && @payload[:action] == 'closed') ||
      (gitlab_merge_request? && ['close', 'merge'].include?(@payload[:action]))
  end

  def reopened_pull_request?
    (github_pull_request? && @payload[:action] == 'reopened') ||
      (gitlab_merge_request? && @payload[:action] == 'reopen')
  end

  def push_event?
    github_push_event? || gitlab_push_event?
  end

  def tag_push_event?
    github_tag_push_event? || gitlab_tag_push_event?
  end

  def pull_request_event?
    github_pull_request? || gitlab_merge_request?
  end

  def ignored_pull_request_action?
    ignored_github_pull_request_action? || ignored_gitlab_merge_request_action?
  end

  private

  def github_push_event?
    @payload[:scm] == 'github' && @payload[:event] == 'push' && @payload.fetch(:ref, '').start_with?('refs/heads/')
  end

  def gitlab_push_event?
    @payload[:scm] == 'gitlab' && @payload[:event] == 'Push Hook'
  end

  def github_tag_push_event?
    @payload[:scm] == 'github' && @payload[:event] == 'push' && @payload.fetch(:ref, '').starts_with?('refs/tags/')
  end

  def gitlab_tag_push_event?
    @payload[:scm] == 'gitlab' && @payload[:event] == 'Tag Push Hook'
  end

  def github_pull_request?
    @payload[:scm] == 'github' && @payload[:event] == 'pull_request'
  end

  def gitlab_merge_request?
    @payload[:scm] == 'gitlab' && @payload[:event] == 'Merge Request Hook'
  end

  def ignored_github_pull_request_action?
    github_pull_request? && IGNORED_PULL_REQUEST_ACTIONS.include?(@payload[:action])
  end

  def ignored_gitlab_merge_request_action?
    gitlab_merge_request? && IGNORED_MERGE_REQUEST_ACTIONS.include?(@payload[:action])
  end
end
