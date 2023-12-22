class Decorators::Notification::Event::ReportForRequest < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a request. This is the reason:"
  end

  def notifiable_link_text(_helpers)
    "Report for Request ##{@notification.notifiable.reportable.number}"
  end

  def notifiable_link_path
    bs_request = notification.notifiable.reportable
    Rails.application.routes.url_helpers.request_show_path(bs_request.number, notification_id: notification.id)
  end

  def avatar_objects
    [User.find(notification.event_payload['user_id'])]
  end
end
