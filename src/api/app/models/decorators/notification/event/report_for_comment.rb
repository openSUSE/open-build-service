class Decorators::Notification::Event::ReportForComment < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a comment from #{notification.event_payload['commenter']}. This is the reason:"
  end
end
