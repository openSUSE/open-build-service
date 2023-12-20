class Decorators::Notification::Event::BuildFail < Decorators::Notification::Common
  def description_text
    "Build was triggered because of #{notification.event_payload['reason']}"
  end

  def notifiable_link_text(_helpers)
    project = notification.event_payload['project']
    package = notification.event_payload['package']
    repository = notification.event_payload['repository']
    arch = notification.event_payload['arch']
    "Package #{package} on #{project} project failed to build against #{repository} / #{arch}"
  end
end
