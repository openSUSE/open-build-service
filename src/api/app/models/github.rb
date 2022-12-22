class Github
  attr_reader :event, :webhook_payload

  def initialize(event, webhook_payload)
    @event = event
    @webhook_payload = webhook_payload
  end

  def default_payload
    {
      scm: 'github',
      event: event,
      api_endpoint: api_endpoint
    }
  end

  private

  def api_endpoint
    sender_url = webhook_payload.dig(:sender, :url)
    return unless sender_url

    host = URI.parse(sender_url).host
    if host.start_with?('api.github.com')
      "https://#{host}"
    else
      "https://#{host}/api/v3/"
    end
  end
end
