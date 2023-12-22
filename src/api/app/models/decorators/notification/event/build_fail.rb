class Decorators::Notification::Event::BuildFail < Decorators::Notification::Common
  def description_text
    "Build was triggered because of #{notification.event_payload['reason']}"
  end
end
