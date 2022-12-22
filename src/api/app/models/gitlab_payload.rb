class GitlabPayload
  attr_reader :event, :http_url, :webhook_payload

  def initialize(event, webhook_payload)
    @event = event
    @webhook_payload = webhook_payload
    @http_url = webhook_payload.dig(:project, :http_url)
  end

  def default_payload
    {
      scm: 'gitlab',
      object_kind: webhook_payload[:object_kind],
      http_url: http_url,
      event: event,
      api_endpoint: api_endpoint
    }
  end

  def payload
    raise AbstractMethodCalled
  end

  private

  def api_endpoint
    return unless http_url

    uri = URI.parse(http_url)
    "#{uri.scheme}://#{uri.host}"
  end
end
