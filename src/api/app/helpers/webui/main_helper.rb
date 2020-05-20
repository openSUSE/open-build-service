module Webui::MainHelper
  def icon_for_status(message)
    case message.severity.to_sym
    when :green
      { class: 'fa-check-circle text-success', title: 'Success' }
    when :yellow
      { class: 'fa-exclamation-triangle text-warning', title: 'Warning' }
    when :red
      { class: 'fa-exclamation-circle text-danger', title: 'Alert' }
    when :announcement
      { class: 'fa-bullhorn text-info', title: 'Announcement' }
    else
      { class: 'fa-info-circle text-info', title: 'Info' }
    end
  end
end
