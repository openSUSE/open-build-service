class NotificationProject < Notification
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

  def avatar_objects
    [User.find_by(login: event_payload['who'])].compact
  end

  def link_text
    case event_type
    when 'Event::RelationshipCreate'
      "Added as #{event_payload['role']} of a project"
    when 'Event::RelationshipDelete'
      "Removed as #{event_payload['role']} of a project"
    end
  end

  def link_path
    Rails.application.routes.url_helpers.project_users_path(event_payload['project'], notification_id: id)
  end
end
