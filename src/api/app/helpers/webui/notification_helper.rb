module Webui::NotificationHelper
  def link_to_show_less_or_more
    parameters = params.slice(:show_more, :type, :project).permit!
    less_or_more = parameters[:show_more] ? 'less' : 'more'
    parameters[:show_more] = parameters[:show_more] ? nil : '1'
    link_to("Show #{less_or_more}", my_notifications_path(parameters))
  end

  private

  def mark_as_read_or_unread_button(notification)
    type = notification.unread? ? 'unread' : 'read'
    update_path = my_notifications_path(notification_ids: [notification.id], type: type)
    title, icon = notification.unread? ? ['Mark as read', 'fa-check'] : ['Mark as unread', 'fa-undo']
    link_to(update_path, id: dom_id(notification, :update), method: :put,
                         class: 'btn btn-sm btn-outline-success', title: title) do
      concat(tag.i(class: "#{icon} fas"))
      concat(" #{title}")
    end
  end
end
