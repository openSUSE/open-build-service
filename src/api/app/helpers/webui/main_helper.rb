module Webui::MainHelper
  def proceed_link(image, text, link_opts)
    content_tag(:li,
                link_to(sprite_tag(image, title: text), link_opts) + tag(:br) +
                content_tag(:span, link_to(text, link_opts), class: 'proceed_text'))
  end

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
