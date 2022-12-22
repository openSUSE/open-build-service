class GiteaPayload::PullRequest
  attr_reader :event, :webhook_payload

  def initialize(event, webhook_payload)
    @event = event
    @webhook_payload = webhook_payload
  end

  def payload
    http_url = webhook_payload.dig(:repository, :clone_url)
    payload = {
      scm: 'gitea',
      event: event,
      api_endpoint: gitea_api_endpoint(http_url),
      http_url: http_url
    }

    payload.merge(commit_sha: webhook_payload.dig(:pull_request, :head, :sha),
                  pr_number: webhook_payload[:number],
                  source_branch: webhook_payload.dig(:pull_request, :head, :ref),
                  target_branch: webhook_payload.dig(:pull_request, :base, :ref),
                  action: webhook_payload[:action],
                  source_repository_full_name: webhook_payload.dig(:pull_request, :head, :repo, :full_name),
                  target_repository_full_name: webhook_payload.dig(:pull_request, :base, :repo, :full_name))
  end

  private

  def gitea_api_endpoint(http_url)
    url = URI.parse(http_url)

    "#{url.scheme}://#{url.host}"
  end
end
