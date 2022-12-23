# This class is used in TriggerControllerService::ScmExtractor to handle pull request events coming from Github.
class GithubPayload::PullRequest < GithubPayload
  def payload
    default_payload.merge(
      event: 'pull_request',
      commit_sha: webhook_payload.dig(:pull_request, :head, :sha),
      pr_number: webhook_payload[:number],
      source_branch: webhook_payload.dig(:pull_request, :head, :ref),
      target_branch: webhook_payload.dig(:pull_request, :base, :ref),
      action: webhook_payload[:action],
      source_repository_full_name: webhook_payload.dig(:pull_request, :head, :repo, :full_name),
      target_repository_full_name: webhook_payload.dig(:pull_request, :base, :repo, :full_name)
    )
  end
end
