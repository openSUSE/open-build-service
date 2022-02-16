class NotificationExcerptComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_excerpt_component/preview
  def preview
    render(NotificationExcerptComponent.new(Notification.last))
  end
end
