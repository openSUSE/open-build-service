# Methods to know which webhook we are dealing with based on the request_payload attribute
module WorkflowRunGithubPayload
  extend ActiveSupport::Concern

  ALLOWED_GITHUB_EVENTS = %w[pull_request push ping].freeze
  ALLOWED_GITHUB_PULL_REQUEST_ACTIONS = %w[closed opened reopened synchronize synchronized].freeze

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

  def github_target_repository_full_name
    return payload.dig(:pull_request, :base, :repo, :full_name) if github_pull_request?

    payload.dig(:repository, :full_name) if github_push_event? || github_tag_push_event?
  end

  def github_pr_number
    payload[:number]
  end

  def github_checkout_http_url
    payload.dig(:repository, :clone_url)
  end

  def github_tag_name
    payload.fetch(:ref, '').sub('refs/tags/', '')
  end

  def github_target_branch
    return payload.dig(:pull_request, :base, :ref) if github_pull_request?
    return payload.fetch(:ref, '').sub('refs/heads/', '') if github_push_event?

    payload.dig(:head_commit, :id) if github_tag_push_event?
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
    scm_vendor == 'github' && hook_event == 'push' && payload.fetch(:ref, '').start_with?('refs/heads/')
  end

  def github_tag_push_event?
    scm_vendor == 'github' && hook_event == 'push' && payload.fetch(:ref, '').starts_with?('refs/tags/')
  end

  def github_pull_request?
    scm_vendor == 'github' && hook_event == 'pull_request'
  end

  def github_ping?
    scm_vendor == 'github' && hook_event == 'ping'
  end

  def github_supported_event?
    scm_vendor == 'github' && ALLOWED_GITHUB_EVENTS.include?(hook_event)
  end

  def github_supported_pull_request_action?
    github_pull_request? && ALLOWED_GITHUB_PULL_REQUEST_ACTIONS.include?(hook_action)
  end

  def github_supported_push_action?
    github_push_event? && !payload[:deleted]
  end

  def github_new_pull_request?
    github_pull_request? && github_hook_action == 'opened'
  end

  def github_updated_pull_request?
    github_pull_request? && github_hook_action == 'synchronize'
  end

  def github_closed_merged_pull_request?
    github_pull_request? && github_hook_action == 'closed'
  end

  def github_reopened_pull_request?
    github_pull_request? && github_hook_action == 'reopened'
  end
end
