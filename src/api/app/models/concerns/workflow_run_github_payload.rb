# Methods to know which webhook we are dealing with based on the request_payload attribute
class WorkflowRunGithubPayload
  extend ActiveSupport::Concern

  ALLOWED_PULL_REQUEST_ACTIONS = %w[closed opened reopened synchronize synchronized].freeze

  private

  def github_commit_sha
    return payload.dig(:pull_request, :head, :sha) if github_pull_request?
    return payload[:after] if github_push_event?

    payload.dig(:head_commit, :id) if github_tag_push_event?
  end

  def github_source_repository_full_name
    return payload.dig(:pull_request, :head, :repo, :full_name) if github_pull_request?

    payload.dig(:repository, :full_name) if github_push_event? || github_tag_push_event?
  end

  def github_repository_name
    payload.dig('repository', 'name')
  end

  def github_repository_owner
    payload.dig('repository', 'owner', 'login')
  end

  def github_hook_action
    payload['action']
  end

  def github_api_endpoint
    sender_url = payload.dig(:sender, :url)
    return unless sender_url

    host = URI.parse(sender_url).host
    if host.start_with?('api.github.com')
      "https://#{host}"
    else
      "https://#{host}/api/v3/"
    end
  end

  def github_push_event?
    scm_vendor == 'github' && payload[:event] == 'push' && payload.fetch(:ref, '').start_with?('refs/heads/')
  end

  def github_tag_push_event?
    scm_vendor == 'github' && payload[:event] == 'push' && payload.fetch(:ref, '').starts_with?('refs/tags/')
  end

  def github_pull_request?
    scm_vendor == 'github' && payload[:event] == 'pull_request'
  end

  def github_ping?
    scm_vendor == 'github' && payload[:event] == 'ping'
  end

  def ignored_github_pull_request_action?
    github_pull_request? && ALLOWED_PULL_REQUEST_ACTIONS.exclude?(payload[:action])
  end

  def ignored_github_push_event?
    github_push_event? && payload[:deleted]
  end
end
