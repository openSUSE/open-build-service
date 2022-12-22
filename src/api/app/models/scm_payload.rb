class ScmPayload
  attr_reader :webhook_payload

  def initialize(webhook_payload)
    @webhook_payload = webhook_payload
  end

  def default_payload
    raise AbstractMethodCalled
  end

  def payload
    raise AbstractMethodCalled
  end
end
