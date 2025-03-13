# Methods to fetch information from a GitLab webhook payload
module WorkflowRunGitlabPayload
  extend ActiveSupport::Concern

  ALLOWED_GITLAB_EVENTS = ['Merge Request Hook', 'Push Hook', 'Tag Push Hook'].freeze
  ALLOWED_GITLAB_PULL_REQUEST_ACTIONS = %w[close merge open reopen update].freeze

  def gitlab_project_id
    return payload.dig(:object_attributes, :source_project_id) if gitlab_merge_request?

    payload[:project_id] if gitlab_push_event? || gitlab_tag_push_event?
  end

  def gitlab_path_with_namespace
    payload.dig(:project, :path_with_namespace) if gitlab_push_event? || gitlab_tag_push_event?
  end

  private

  def gitlab_commit_sha
    return payload.dig(:object_attributes, :last_commit, :id) if gitlab_merge_request?

    payload[:after] if gitlab_push_event? || gitlab_tag_push_event?
  end

  def gitlab_source_repository_full_name
    return payload.dig(:object_attributes, :source, :path_with_namespace) if gitlab_merge_request?

    payload.dig(:project, :path_with_namespace) if gitlab_push_event? || gitlab_tag_push_event?
  end

  def gitlab_target_repository_full_name
    return payload.dig(:object_attributes, :target, :path_with_namespace) if gitlab_merge_request?

    payload.dig(:project, :path_with_namespace) if gitlab_push_event? || gitlab_tag_push_event?
  end

  def gitlab_pr_number
    payload.dig(:object_attributes, :iid)
  end

  def gitlab_checkout_http_url
    payload.dig(:project, :http_url)
  end

  def gitlab_tag_name
    payload[:ref].sub('refs/tags/', '')
  end

  def gitlab_target_branch
    return payload.dig(:object_attributes, :target_branch) if gitlab_merge_request?
    return payload[:ref].sub('refs/heads/', '') if gitlab_push_event?

    payload[:after] if gitlab_tag_push_event?
  end

  def gitlab_api_endpoint
    project_url = payload.dig(:project, :http_url)
    return unless project_url

    uri = URI.parse(project_url)
    "#{uri.scheme}://#{uri.host}"
  end

  def gitlab_push_event?
    scm_vendor == 'gitlab' && hook_event == 'Push Hook'
  end

  def gitlab_tag_push_event?
    scm_vendor == 'gitlab' && hook_event == 'Tag Push Hook'
  end

  def gitlab_merge_request?
    scm_vendor == 'gitlab' && hook_event == 'Merge Request Hook'
  end

  def gitlab_supported_event?
    scm_vendor == 'gitlab' && ALLOWED_GITLAB_EVENTS.include?(hook_event)
  end

  def gitlab_supported_merge_request_action?
    gitlab_merge_request? && ALLOWED_MERGE_REQUEST_ACTIONS.include?(hook_action)
  end

  def gitlab_supported_push_action?
    # In Push Hook events to delete a branch, the after field is '0000000000000000000000000000000000000000'
    gitlab_push_event? && !payload[:commit_sha].match?(/\A0+\z/)
  end

  def gitlab_new_pull_request?
    gitlab_merge_request? && hook_action == 'open'
  end

  def gitlab_updated_pull_request?
    gitlab_merge_request? && hook_action == 'update'
  end

  def gitlab_closed_merged_pull_request?
    gitlab_merge_request? && %w[close merge].include?(hook_action)
  end

  def gitlab_reopened_pull_request?
    gitlab_merge_request? && hook_action == 'reopen'
  end

  # These methods are just to ensure consistent because github and gitea support labels
  def gitlab_merge_request_label
    nil
  end

  def gitlab_labeled_merge_request?
    false
  end

  def gitlab_unlabeled_merge_request?
    false
  end
end
