class Decorators::Notification::Event::ReportForRequest < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a request. This is the reason:"
  end
end
