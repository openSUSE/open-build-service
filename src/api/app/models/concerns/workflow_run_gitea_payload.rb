# Methods to fetch information from a Gitea webhook payload
module WorkflowRunGiteaPayload
  extend ActiveSupport::Concern

  ALLOWED_GITEA_EVENTS = %w[pull_request push ping].freeze
  ALLOWED_GITEA_PULL_REQUEST_ACTIONS = %w[closed opened reopened synchronize synchronized labeled unlabeled].freeze

  private

  def gitea_commit_sha
    return payload.dig(:pull_request, :head, :sha) if gitea_pull_request?
    return payload.dig(:head_commit, :id) if gitea_tag_push_event?

    payload[:after]
  end

  def gitea_source_repository_full_name
    return payload.dig(:pull_request, :head, :repo, :full_name) if gitea_pull_request?

    payload.dig(:repository, :full_name)
  end

  def gitea_target_repository_full_name
    return payload.dig(:pull_request, :base, :repo, :full_name) if gitea_pull_request?

    payload.dig(:repository, :full_name)
  end

  def gitea_target_branch
    return payload.dig(:pull_request, :base, :ref) if gitea_pull_request?
    return payload.dig(:head_commit, :id) if gitea_tag_push_event?

    payload.fetch(:ref, '').sub('refs/heads/', '')
  end

  def gitea_api_endpoint
    repositoy_url = payload.dig(:repository, :clone_url)
    return unless repositoy_url

    url = URI.parse(repositoy_url)
    "#{url.scheme}://#{url.host}"
  end

  def gitea_push_event?
    scm_vendor == 'gitea' && hook_event == 'push' && payload.fetch(:ref, '').start_with?('refs/heads/')
  end

  def gitea_tag_push_event?
    scm_vendor == 'gitea' && hook_event == 'push' && payload.fetch(:ref, '').starts_with?('refs/tags/')
  end

  def gitea_pull_request?
    scm_vendor == 'gitea' && hook_event == 'pull_request'
  end

  def gitea_ping?
    scm_vendor == 'gitea' && hook_event == 'ping'
  end

  def gitea_new_pull_request?
    gitea_pull_request? && hook_action == 'opened'
  end

  def gitea_updated_pull_request?
    gitea_pull_request? && hook_action == 'synchronized'
  end

  def gitea_closed_merged_pull_request?
    gitea_pull_request? && hook_action == 'closed'
  end

  def gitea_reopened_pull_request?
    gitea_pull_request? && hook_action == 'reopened'
  end

  def gitea_checkout_http_url
    payload.dig(:repository, :clone_url)
  end

  def gitea_tag_name
    payload.fetch(:ref, '').sub('refs/tags/', '')
  end

  def gitea_pr_number
    payload[:number]
  end

  def gitea_pull_request_label
    payload.dig(:label, :name)
  end

  def gitea_labeled_pull_request?
    gitea_pull_request? && hook_action == 'labeled'
  end

  def gitea_unlabeled_pull_request?
    gitea_pull_request? && hook_action == 'unlabeled'
  end
end
