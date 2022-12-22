class GiteaPayload
  attr_reader :event, :http_url, :webhook_payload

  def initialize(event, webhook_payload)
    @event = event
    @webhook_payload = webhook_payload
    @http_url = webhook_payload.dig(:repository, :clone_url)
  end

  def default_payload
    {
      scm: 'gitea',
      event: event,
      api_endpoint: api_endpoint,
      http_url: http_url
    }
  end

  def payload
    raise AbstractMethodCalled
  end

  private

  def api_endpoint
    url = URI.parse(http_url)

    "#{url.scheme}://#{url.host}"
  end
end
