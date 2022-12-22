class GiteaPayloadExtractor < ScmPayloadExtractor
  attr_reader :event, :webhook_payload

  def initialize(event, webhook_payload)
    super()
    @event = event
    @webhook_payload = webhook_payload
  end

  def payload
    case event
    when 'pull_request'
      GiteaPayload::PullRequest.new(event, webhook_payload).payload
    when 'push' # GitHub doesn't have different push events for commits and tags
      GiteaPayload::Push.new(event, webhook_payload).payload
    end
  end
end
