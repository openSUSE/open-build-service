class Decorators::Notification::Event::ReportForRequest < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a request. This is the reason:"
  end

  def notifiable_link_text(_helpers)
    "Report for Request ##{@notification.notifiable.reportable.number}"
  end
end
