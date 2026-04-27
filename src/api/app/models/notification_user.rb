class NotificationUser < Notification
  def description
    subscriber_name = subscriber.login == event_payload['user'] ? 'you' : event_payload['user']
    "'#{event_payload['who']}' gave the '#{event_payload['role']}' role to '#{subscriber_name}'"
  end

  def excerpt
    ''
  end

  def avatar_objects
    User.where(login: event_payload['who'])
  end

  def link_text
    'New Global Role Assigned'
  end

  def link_path
    return unless User.exists?(login: event_payload['user'])

    Rails.application.routes.url_helpers.user_path(event_payload['user'], notification_id: id)
  end
end
