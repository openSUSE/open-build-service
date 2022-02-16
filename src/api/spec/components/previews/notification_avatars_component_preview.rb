class NotificationAvatarsComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_avatars_component/preview
  def preview
    render(NotificationAvatarsComponent.new(Notification.last))
  end
end
