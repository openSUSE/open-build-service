module Webui::StatusMessageHelper
  def status_message_severity_class(message)
    case message.severity.to_i
    when 3
      'border-danger'
    when 2
      'border-warning'
    when 1
      'border-success'
    else
      ''
    end
  end
end
