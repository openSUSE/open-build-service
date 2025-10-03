# Methods to abstract GitHub/GitLab/Gitea webhook payloads
module WorkflowRunPayload
  extend ActiveSupport::Concern

  def new_pull_request?
    github_new_pull_request? || gitlab_new_pull_request? || gitea_new_pull_request?
  end

  def updated_pull_request?
    github_updated_pull_request? || gitlab_updated_pull_request? || gitea_updated_pull_request?
  end

  def closed_merged_pull_request?
    github_closed_merged_pull_request? || gitlab_closed_merged_pull_request? || gitea_closed_merged_pull_request?
  end

  def reopened_pull_request?
    github_reopened_pull_request? || gitlab_reopened_pull_request? || gitea_reopened_pull_request?
  end

  def new_commit_event?
    new_pull_request? || updated_pull_request? || push_event? || tag_push_event?
  end

  def push_event?
    github_push_event? || gitlab_push_event? || gitea_push_event?
  end

  def committed_push_event?
    github_committed_push_event? || gitlab_committed_push_event? || gitea_committed_push_event?
  end

  def deleted_push_event?
    github_deleted_push_event? || gitlab_deleted_push_event? || gitea_deleted_push_event?
  end

  def tag_push_event?
    github_tag_push_event? || gitlab_tag_push_event? || gitea_tag_push_event?
  end

  def pull_request_event?
    github_pull_request? || gitlab_merge_request? || gitea_pull_request?
  end

  def ping_event?
    github_ping? || gitea_ping?
  end

  def commit_sha
    github_commit_sha || gitlab_commit_sha || gitea_commit_sha
  end

  def source_repository_full_name
    github_source_repository_full_name || gitlab_source_repository_full_name || gitea_source_repository_full_name
  end

  def target_repository_full_name
    github_target_repository_full_name || gitlab_target_repository_full_name || gitea_target_repository_full_name
  end

  def pr_number
    github_pr_number || gitea_pr_number || gitlab_pr_number
  end

  def checkout_http_url
    github_checkout_http_url || gitea_checkout_http_url || gitlab_checkout_http_url
  end

  def tag_name
    github_tag_name || gitea_tag_name || gitlab_tag_name
  end

  def target_branch
    github_target_branch || gitlab_target_branch || gitea_target_branch
  end

  def api_endpoint
    github_api_endpoint || gitlab_api_endpoint || gitea_api_endpoint
  end

  def label
    github_pull_request_label || gitea_pull_request_label || gitlab_merge_request_label
  end

  def labeled_pull_request?
    github_labeled_pull_request? || gitea_labeled_pull_request? || gitlab_labeled_merge_request?
  end

  def unlabeled_pull_request?
    github_unlabeled_pull_request? || gitea_unlabeled_pull_request? || gitlab_unlabeled_merge_request?
  end

  private

  def payload_generic_event_type
    # We only have filters for push, tag_push, and pull_request
    if push_event?
      'push'
    elsif tag_push_event?
      'tag_push'
    elsif pull_request_event?
      'pull_request'
    end
  end

  def payload_event_source_name
    github_event_source_name || gitlab_event_source_name
  end

  def payload_repository_name
    payload.dig('repository', 'name') || payload.dig('project', 'path_with_namespace')&.split('/')&.last
  end

  def payload_repository_owner
    payload.dig('repository', 'owner', 'login') || payload.dig('project', 'path_with_namespace')&.split('/')&.first
  end

  def payload_hook_action
    payload['action'] || payload.dig('object_attributes', 'action') || push_hook_action
  end

  def push_hook_action
    return 'committed' if committed_push_event?
    return 'deleted' if deleted_push_event?
    return 'tagged' if tag_push_event?

    'unknown'
  end
end
