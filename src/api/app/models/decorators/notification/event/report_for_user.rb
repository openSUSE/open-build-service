class Decorators::Notification::Event::ReportForUser < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a #{notification.event_payload['reportable_type'].downcase}. This is the reason:"
  end
end
