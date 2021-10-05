class NotificationActionBarComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_action_bar_component/type_read
  def type_read
    render(NotificationActionBarComponent.new(type: 'read', update_path: 'my/notifications?type=read&update_all=true', show_read_all_button: true))
  end

  # Preview at http://HOST:PORT/rails/view_components/notification_action_bar_component/type_unread
  def type_unread
    render(NotificationActionBarComponent.new(type: 'unread', update_path: 'my/notifications?type=unread&update_all=true', show_read_all_button: true))
  end
end
