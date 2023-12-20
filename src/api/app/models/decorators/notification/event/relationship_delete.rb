class Decorators::Notification::Event::RelationshipDelete
  def description_text
    role = notification.event_payload['role']
    user = notification.event_payload['who']
    recipient = notification.event_payload.fetch('group', 'you')
    project = notification.event_payload['project']
    package = notification.event_payload['package']
    target_object = [project, package].compact.join(' / ')
    "#{user} removed #{recipient} as #{role} of #{target_object}"
  end

  def notifiable_link_text(_helpers)
    role = notification.event_payload['role']
    if notification.event_payload['package']
      "Removed as #{role} of a package"
    else
      "Removed as #{role} of a project"
    end
  end
end
