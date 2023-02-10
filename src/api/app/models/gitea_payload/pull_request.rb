# This class is used in TriggerControllerService::ScmExtractor to handle pull requests events coming from Gitea.
# It's basically the same than the pull requests coming from Github but with some customizations on top.
class GiteaPayload::PullRequest < GithubPayload::PullRequest
  def payload
    super.merge(scm: 'gitea',
                http_url: http_url,
                api_endpoint: api_endpoint)
  end

  private

  def http_url
    webhook_payload.dig(:repository, :clone_url)
  end

  def api_endpoint
    url = URI.parse(http_url)

    "#{url.scheme}://#{url.host}"
  end
end
