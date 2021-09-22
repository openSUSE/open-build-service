# Contains the payload extracted from a SCM webhook and provides helper methods to know which webhook event we're dealing with
class ScmWebhook
  include ActiveModel::Model

  attr_accessor :payload

  validates_with ScmWebhookEventValidator

  def initialize(attributes = {})
    super
    # To safely navigate the hash and compare keys
    @payload = attributes[:payload].deep_symbolize_keys
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

  def pull_request_event?
    github_pull_request? || gitlab_merge_request?
  end

  private

  def github_push_event?
    @payload[:scm] == 'github' && @payload[:event] == 'push'
  end

  def gitlab_push_event?
    @payload[:scm] == 'gitlab' && @payload[:event] == 'Push Hook'
  end

  def github_pull_request?
    @payload[:scm] == 'github' && @payload[:event] == 'pull_request'
  end

  def gitlab_merge_request?
    @payload[:scm] == 'gitlab' && @payload[:event] == 'Merge Request Hook'
  end
end
