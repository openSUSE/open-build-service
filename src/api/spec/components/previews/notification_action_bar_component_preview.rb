class NotificationActionBarComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_action_bar_component/state_read
  def state_read
    render(NotificationActionBarComponent.new(state: 'read', update_path: 'my/notifications?state=read&update_all=true', counted_notifications: { all: 301 }.with_indifferent_access))
  end

  # Preview at http://HOST:PORT/rails/view_components/notification_action_bar_component/state_unread
  def state_unread
    render(NotificationActionBarComponent.new(state: 'unread', update_path: 'my/notifications?state=unread&update_all=true', counted_notifications: { all: 301 }.with_indifferent_access))
  end
end
