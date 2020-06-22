module Webui::NotificationHelper
  def link_to_all
    parameters = params[:type] ? { type: params[:type] } : {}
    if params['show_all'] # already showing all
      link_to('Show less', my_notifications_path(parameters), class: 'btn btn-sm btn-secondary ml-2')
    else
      parameters.merge!({ show_all: 1 })
      link_to('Show all', my_notifications_path(parameters), class: 'btn btn-sm btn-secondary ml-2')
    end
  end

  def filter_notification_link(link_text, amount, filter_item)
    link_to(my_notifications_path(filter_item), class: filter_css(filter_item)) do
      concat(link_text)
      concat(tag.span(amount, class: "badge #{badge_color(filter_item)} align-text-top ml-2")) if amount && amount.positive?
    end
  end

  private

  def filter_css(filter_item)
    css_class = 'list-group-item list-group-item-action'
    css_class += ' active' if notification_filter_active?(filter_item)
    css_class
  end

  def notification_filter_active?(filter_item)
    if params[:project].present?
      filter_item[:project] == params[:project]
    elsif params[:type].present?
      filter_item[:type] == params[:type]
    else
      filter_item[:type] == 'unread'
    end
  end

  def badge_color(filter_item)
    notification_filter_active?(filter_item) ? 'badge-light' : 'badge-primary'
  end
end
