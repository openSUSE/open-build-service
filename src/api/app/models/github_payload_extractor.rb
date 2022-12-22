class GithubPayloadExtractor < ScmPayloadExtractor
  attr_reader :event, :webhook_payload

  def initialize(event, webhook_payload)
    super()
    @event = event
    @webhook_payload = webhook_payload
  end

  def payload
    payload = {
      scm: 'github',
      event: event,
      api_endpoint: github_api_endpoint
    }

    case event
    when 'pull_request'
      return Github::PullRequest.new(event, webhook_payload).payload
    when 'push' # GitHub doesn't have different push events for commits and tags
      return Github::Push.new(event, webhook_payload).payload
    end

    payload
  end

  private

  def github_api_endpoint
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
