class NotificationGroup < Notification
  def description
    ''
  end

  def excerpt
    ''
  end

  def avatar_objects
    [User.find_by(login: event_payload['who'])].compact
  end

  def link_text
    case event_type
    when 'Event::AddedUserToGroup'
      "#{event_payload['who'] || 'Someone'} added you to the group '#{event_payload['group']}'"
    when 'Event::RemovedUserFromGroup'
      "#{event_payload['who'] || 'Someone'} removed you from the group '#{event_payload['group']}'"
    end
  end

  def link_path
    return unless Group.exists?(title: event_payload['group'])

    Rails.application.routes.url_helpers.group_path(event_payload['group'])
  end
end
