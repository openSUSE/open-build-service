class GitlabPayloadExtractor
  EVENT_CLASSES = {
    'Merge Request Hook' => GitlabPayload::MergeRequest,
    'Push Hook' => GitlabPayload::Push,
    'Tag Push Hook' => GitlabPayload::TagPush
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
