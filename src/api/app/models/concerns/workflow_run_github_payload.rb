# Methods to fetch information from a GitHub webhook payload
module WorkflowRunGithubPayload
  extend ActiveSupport::Concern

  ALLOWED_GITHUB_EVENTS = %w[pull_request push ping].freeze
  ALLOWED_GITHUB_PULL_REQUEST_ACTIONS = %w[closed opened reopened synchronize synchronized labeled unlabeled].freeze

  private

  def github_commit_sha
    return payload.dig(:pull_request, :head, :sha) if github_pull_request?
    return payload.dig(:head_commit, :id) if github_tag_push_event?

    payload[:after]
  end

  def github_source_repository_full_name
    return payload.dig(:pull_request, :head, :repo, :full_name) if github_pull_request?

    payload.dig(:repository, :full_name)
  end

  def github_target_repository_full_name
    return payload.dig(:pull_request, :base, :repo, :full_name) if github_pull_request?

    payload.dig(:repository, :full_name)
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
    return payload.dig(:head_commit, :id) if github_tag_push_event?

    payload.fetch(:ref, '').sub('refs/heads/', '')
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

  def github_pull_request_label
    payload.dig(:label, :name)
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

  def github_new_pull_request?
    github_pull_request? && hook_action == 'opened'
  end

  def github_updated_pull_request?
    github_pull_request? && hook_action == 'synchronize'
  end

  def github_closed_merged_pull_request?
    github_pull_request? && hook_action == 'closed'
  end

  def github_reopened_pull_request?
    github_pull_request? && hook_action == 'reopened'
  end

  def github_labeled_pull_request?
    github_pull_request? && hook_action == 'labeled'
  end

  def github_unlabeled_pull_request?
    github_pull_request? && hook_action == 'unlabeled'
  end
end
