class GiteaPayload < ScmPayload
  def default_payload
    {
      scm: 'gitea',
      http_url: http_url,
      api_endpoint: api_endpoint
    }
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
