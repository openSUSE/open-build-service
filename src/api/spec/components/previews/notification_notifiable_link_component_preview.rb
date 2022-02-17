class NotificationNotifiableLinkComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_notifiable_link_component/with_bs_request_notifiable
  def with_bs_request_notifiable
    render(NotificationNotifiableLinkComponent.new(Notification.where(notifiable_type: 'BsRequest').first))
  end

  # Preview at http://HOST:PORT/rails/view_components/notification_notifiable_link_component/with_comment_notifiable
  def with_comment_notifiable
    render(NotificationNotifiableLinkComponent.new(Notification.where(notifiable_type: 'Comment').first))
  end
end
