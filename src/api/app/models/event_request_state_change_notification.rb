class EventRequestStateChangeNotification < Notification
  def notifiable_link_text
    "#{helpers.request_type_of_action(notifiable)} Request ##{notifiable.number}"
  end

  def notifiable_link_path
    Rails.application.routes.url_helpers.request_show_path(notifiable.number, notification_id: id)
  end
end
