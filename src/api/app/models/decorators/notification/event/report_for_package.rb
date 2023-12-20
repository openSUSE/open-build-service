class Decorators::Notification::Event::ReportForPackage < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a #{notification.event_payload['reportable_type'].downcase}. This is the reason:"
  end

  def notifiable_link_text(_helpers)
    notification.event_type.constantize.notification_link_text(notification.event_payload)
  end
end
