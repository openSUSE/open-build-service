class Decorators::Notification::Event::ReportForUser < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a #{notification.event_payload['reportable_type'].downcase}. This is the reason:"
  end

  def notifiable_link_text(_helpers)
    "Report for a #{notification.event_payload['reportable_type']}"
  end

  def notifiable_link_path
    Rails.application.routes.url_helpers.user_path(notification.event_payload['user_login'])
  end

  def avatar_objects
    [User.find(notification.event_payload['user_id'])]
  end
end
