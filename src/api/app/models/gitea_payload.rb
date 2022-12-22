class GiteaPayload < ScmPayload
  attr_reader :http_url

  def initialize(webhook_payload)
    super(webhook_payload)
    @http_url = webhook_payload.dig(:repository, :clone_url)
  end

  def default_payload
    {
      scm: 'gitea',
      api_endpoint: api_endpoint,
      http_url: http_url
    }
  end

  private

  def api_endpoint
    url = URI.parse(http_url)

    "#{url.scheme}://#{url.host}"
  end
end
