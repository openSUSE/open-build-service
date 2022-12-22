class GithubPayloadExtractor < ScmPayloadExtractor
  EVENT_CLASSES = {
    'pull_request' => GithubPayload::PullRequest,
    'push' => GithubPayload::Push
  }.freeze

  attr_reader :event, :webhook_payload

  def initialize(event, webhook_payload)
    super()
    @event = event
    @webhook_payload = webhook_payload
  end

  def payload
    # TODO: Implement a null object for when we don't hit any event class
    EVENT_CLASSES[event].new(event, webhook_payload).payload
  end
end
