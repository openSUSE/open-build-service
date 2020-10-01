module Webui::NotificationHelper
  def link_to_all
    parameters = params.slice(:show_all, :type, :project).permit!
    all_or_less = parameters[:show_all] ? 'less' : 'all'
    parameters[:show_all] = parameters[:show_all] ? nil : '1'
    link_to("Show #{all_or_less}", my_notifications_path(parameters))
  end

  def filter_notification_link(link_text, amount, filter_item, selected_filter)
    link_to(my_notifications_path(filter_item), class: css_for_filter_link(filter_item, selected_filter)) do
      concat(link_text)
      concat(tag.span(amount, class: "badge #{badge_color(filter_item, selected_filter)} align-text-top ml-2")) if amount && amount.positive?
    end
  end

  def request_badge_color(state)
    case state
    when :review, :new
      'secondary'
    when :declined, :revoke
      'danger'
    when :superseded
      'warning'
    when :accepted
      'success'
    else
      'dark'
    end
  end

  def action_description(notification)
    case notification.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted', 'Event::CommentForRequest'
      source_and_target(notification)
    when 'Event::CommentForProject'
      "#{notification.notifiable.commentable.name}"
    when 'Event::CommentForPackage'
      commentable = notification.notifiable.commentable
      "#{commentable.project.name} / #{commentable.name}"
    end
  end

  def source_and_target(notification)
    capture do
      if notification.source.present?
        concat(tag.span(notification.source))
        concat(tag.i(nil, class: 'fas fa-long-arrow-alt-right text-info mx-2'))
      end
      concat(tag.span(notification.target))
    end
  end

  private

  def css_for_filter_link(filter_item, selected_filter)
    css_class = 'list-group-item list-group-item-action'
    css_class += ' active' if notification_filter_matches(filter_item, selected_filter)
    css_class
  end

  def notification_filter_matches(filter_item, selected_filter)
    if selected_filter[:project].present?
      filter_item[:project] == selected_filter[:project]
    elsif selected_filter[:type].present?
      filter_item[:type] == selected_filter[:type]
    else
      filter_item[:type] == 'unread'
    end
  end

  def badge_color(filter_item, selected_filter)
    notification_filter_matches(filter_item, selected_filter) ? 'badge-light' : 'badge-primary'
  end

  def mark_as_read_or_unread_button(notification)
    update_path = my_notifications_path(notification_ids: [notification.id])
    title, icon = notification.unread? ? ['Mark as read', 'fa-check'] : ['Mark as unread', 'fa-undo']
    link_to(update_path, id: "update-notification-#{notification.id}", method: :put,
                         class: 'btn btn-sm btn-outline-success', title: title) do
      concat(tag.i(class: "#{icon} fas"))
      concat(" #{title}")
    end
  end
end
