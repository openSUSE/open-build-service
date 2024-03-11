class GiteaPayload < ScmPayload
  def default_payload
    {
      scm: 'gitea',
      http_url: http_url,
      api_endpoint: api_endpoint,
      repository_name: webhook_payload[:target_repository_full_name]
    }.compact
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
