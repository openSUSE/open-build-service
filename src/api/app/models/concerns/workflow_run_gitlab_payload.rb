# Methods to know which webhook we are dealing with based on the request_payload attribute
class WorkflowRunGitlabPayload
  extend ActiveSupport::Concern

  ALLOWED_MERGE_REQUEST_ACTIONS = %w[close merge open reopen update].freeze

  private

  def gitlab_commit_sha
    payload.dig(:object_attributes, :last_commit, :id)
  end

  def gitlab_repository_name
    payload.dig('project', 'path_with_namespace')&.split('/')&.last
  end

  def gitlab_repository_owner
    payload.dig('project', 'path_with_namespace')&.split('/')&.first
  end

  def gitlab_hook_action
    payload.dig('object_attributes', 'action')
  end

  def gitlab_api_endpoint
    project_url = payload.dig(:project, :http_url)
    return unless project_url

    uri = URI.parse(project_url)
    "#{uri.scheme}://#{uri.host}"
  end

  def gitlab_push_event?
    scm_vendor == 'gitlab' && payload[:event] == 'Push Hook'
  end

  def gitlab_tag_push_event?
    scm_vendor == 'gitlab' && payload[:event] == 'Tag Push Hook'
  end

  def gitlab_merge_request?
    scm_vendor == 'gitlab' && payload[:event] == 'Merge Request Hook'
  end

  def ignored_gitlab_merge_request_action?
    gitlab_merge_request? && ALLOWED_MERGE_REQUEST_ACTIONS.exclude?(payload[:action])
  end

  def ignored_gitlab_push_event?
    # In Push Hook events to delete a branch, the after field is '0000000000000000000000000000000000000000'
    gitlab_push_event? && payload[:commit_sha].match?(/\A0+\z/)
  end
end
