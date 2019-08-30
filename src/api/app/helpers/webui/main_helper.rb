module Webui::MainHelper
  def icon_for_status(message)
    case message.severity
    when 1
      { class: 'fa-check-circle text-success', title: 'Success' }
    when 2
      { class: 'fa-exclamation-triangle text-warning', title: 'Warning' }
    when 3
      { class: 'fa-exclamation-circle text-danger', title: 'Alert' }
    else
      { class: 'fa-info-circle text-info', title: 'Info' }
    end
  end
end
