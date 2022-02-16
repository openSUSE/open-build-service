class NotificationActionDescriptionComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_action_description_component/preview
  def preview
    render(NotificationActionDescriptionComponent.new(Notification.last))
  end
end
