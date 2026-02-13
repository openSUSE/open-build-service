class NotificationToken < Notification
  def description
    'Token disabled'
  end

  def excerpt
    "Your token '#{notifiable.name}' was disabled"
  end

  def avatar_objects
    [notifiable.user]
  end

  def link_text
    'Token'
  end

  def link_path
    return if notifiable.blank?

    Rails.application.routes.url_helpers.token_path(notifiable, notification_id: id)
  end
end
