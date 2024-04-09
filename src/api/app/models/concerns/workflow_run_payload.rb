# Methods to know which webhook we are dealing with based on the request_payload attribute
class WorkflowRunPayload
  extend ActiveSupport::Concern

  ALLOWED_PULL_REQUEST_ACTIONS = %w[closed opened reopened synchronize synchronized].freeze
  ALLOWED_MERGE_REQUEST_ACTIONS = %w[close merge open reopen update].freeze
  ALL_POSSIBLE_REQUEST_ACTIONS = ['all'] + ALLOWED_PULL_REQUEST_ACTIONS + ALLOWED_MERGE_REQUEST_ACTIONS

  SOURCE_NAME_PAYLOAD_MAPPING = {
    'pull_request' => %w[pull_request number],
    'Merge Request Hook' => %w[object_attributes iid],
    'push' => %w[head_commit id],
    'Push Hook' => ['commits', 0, 'id']
  }.freeze

  def new_pull_request?
    (github_pull_request? && payload[:action] == 'opened') ||
      (gitlab_merge_request? && payload[:action] == 'open') ||
      (gitea_pull_request? && payload[:action] == 'opened')
  end

  def updated_pull_request?
    (github_pull_request? && payload[:action] == 'synchronize') ||
      (gitlab_merge_request? && payload[:action] == 'update') ||
      (gitea_pull_request? && payload[:action] == 'synchronized')
  end

  def closed_merged_pull_request?
    (github_pull_request? && payload[:action] == 'closed') ||
      (gitlab_merge_request? && %w[close merge].include?(payload[:action])) ||
      (gitea_pull_request? && payload[:action] == 'closed')
  end

  def reopened_pull_request?
    (github_pull_request? && payload[:action] == 'reopened') ||
      (gitlab_merge_request? && payload[:action] == 'reopen') ||
      (gitea_pull_request? && payload[:action] == 'reopened')
  end

  def new_commit_event?
    new_pull_request? || updated_pull_request? || push_event? || tag_push_event?
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

  def payload_generic_event_type
    # We only have filters for push, tag_push, and pull_request
    if hook_event == 'Push Hook' || payload.fetch('ref', '').match('refs/heads')
      'push'
    elsif hook_event == 'Tag Push Hook' || payload.fetch('ref', '').match('refs/tag')
      'tag_push'
    elsif hook_event.in?(['pull_request', 'Merge Request Hook'])
      'pull_request'
    end
  end

  def payload_event_source_name
    path = SOURCE_NAME_PAYLOAD_MAPPING[hook_event]
    payload.dig(*path) if path
  end

  def payload_repository_name
    payload.dig('repository', 'name') || payload.dig('project', 'path_with_namespace')&.split('/')&.last
  end

  def payload_repository_owner
    payload.dig('repository', 'owner', 'login') || payload.dig('project', 'path_with_namespace')&.split('/')&.first
  end

  def payload_hook_action
    payload['action'] || payload.dig('object_attributes', 'action')
  end

  private

  def github_push_event?
    scm_vendor == 'github' && payload[:event] == 'push' && payload.fetch(:ref, '').start_with?('refs/heads/')
  end

  def gitlab_push_event?
    scm_vendor == 'gitlab' && payload[:event] == 'Push Hook'
  end

  def gitea_push_event?
    scm_vendor == 'gitea' && payload[:event] == 'push' && payload.fetch(:ref, '').start_with?('refs/heads/')
  end

  def github_tag_push_event?
    scm_vendor == 'github' && payload[:event] == 'push' && payload.fetch(:ref, '').starts_with?('refs/tags/')
  end

  def gitlab_tag_push_event?
    scm_vendor == 'gitlab' && payload[:event] == 'Tag Push Hook'
  end

  def gitea_tag_push_event?
    scm_vendor == 'gitea' && payload[:event] == 'push' && payload.fetch(:ref, '').starts_with?('refs/tags/')
  end

  def github_pull_request?
    scm_vendor == 'github' && payload[:event] == 'pull_request'
  end

  def gitlab_merge_request?
    scm_vendor == 'gitlab' && payload[:event] == 'Merge Request Hook'
  end

  def gitea_pull_request?
    scm_vendor == 'gitea' && payload[:event] == 'pull_request'
  end

  def github_ping?
    scm_vendor == 'github' && payload[:event] == 'ping'
  end

  def gitea_ping?
    scm_vendor == 'gitea' && payload[:event] == 'ping'
  end

  def ignored_github_pull_request_action?
    github_pull_request? && ALLOWED_PULL_REQUEST_ACTIONS.exclude?(payload[:action])
  end

  def ignored_gitlab_merge_request_action?
    gitlab_merge_request? && ALLOWED_MERGE_REQUEST_ACTIONS.exclude?(payload[:action])
  end

  def ignored_gitea_pull_request_action?
    gitea_pull_request? && ALLOWED_PULL_REQUEST_ACTIONS.exclude?(payload[:action])
  end

  def ignored_github_push_event?
    github_push_event? && payload[:deleted]
  end

  def ignored_gitlab_push_event?
    # In Push Hook events to delete a branch, the after field is '0000000000000000000000000000000000000000'
    gitlab_push_event? && payload[:commit_sha].match?(/\A0+\z/)
  end
end
