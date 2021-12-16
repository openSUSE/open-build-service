module Webui::NotificationHelper
  def link_to_show_less_or_more
    parameters = params.slice(:show_more, :type, :project).permit!
    less_or_more = parameters[:show_more] ? 'less' : 'more'
    parameters[:show_more] = parameters[:show_more] ? nil : '1'
    link_to("Show #{less_or_more}", my_notifications_path(parameters))
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
