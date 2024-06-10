class NotificationProject < Notification
  # TODO: rename to title once we get rid of Notification#title
  def summary
    case event_type
    when 'Event::RelationshipCreate'
      "Added as #{event_payload['role']} of a project"
    when 'Event::RelationshipDelete'
      "Removed as #{event_payload['role']} of a project"
    end
  end

  def description
    # If a notification is for a group, the notified user needs to know for which group. Otherwise, the user is simply referred to as 'you'.
    recipient = event_payload.fetch('group', 'you')
    target_object = [event_payload['project'], event_payload['package']].compact.join(' / ')

    case event_type
    when 'Event::RelationshipCreate'
      "#{event_payload['who']} made #{recipient} #{event_payload['role']} of #{target_object}"
    when 'Event::RelationshipDelete'
      "#{event_payload['who']} removed #{recipient} as #{event_payload['role']} of #{target_object}"
    end
  end

  def excerpt
    ''
  end

  def involved_users
    [User.find_by(login: event_payload['who'])]
  end
end
