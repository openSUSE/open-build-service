class NotificationMarkButtonComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_mark_button_component/unread
  def unread
    render(NotificationMarkButtonComponent.new(Notification.new(id: 123, delivered: false),
                                               selected_filter: { type: 'unread',
                                                                  projects_for_filter: { OBS: 1 },
                                                                  groups_for_filter: { heroes: 1 } }))
  end

  # Preview at http://HOST:PORT/rails/view_components/notification_mark_button_component/read
  def read
    render(NotificationMarkButtonComponent.new(Notification.new(id: 123, delivered: true),
                                               selected_filter: { type: 'read',
                                                                  projects_for_filter: { OBS: 1 },
                                                                  groups_for_filter: { heroes: 1 } }))
  end
end
