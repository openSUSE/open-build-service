class NotificationFilterLinkComponentPreview < ViewComponent::Preview
  # # Preview at http://HOST:PORT/rails/view_components/notification_filter_link_component/active_with_badge
  def active_with_badge
    render(NotificationFilterLinkComponent.new(text: 'Requests', filter_item: { type: 'requests' },
                                               selected_filter: { type: 'requests' }, amount: 20))
  end

  # # Preview at http://HOST:PORT/rails/view_components/notification_filter_link_component/with_badge
  def with_badge
    render(NotificationFilterLinkComponent.new(text: 'Requests', filter_item: { type: 'requests' },
                                               selected_filter: { type: 'comments' }, amount: 20))
  end

  # # Preview at http://HOST:PORT/rails/view_components/notification_filter_link_component/active_without_badge
  def active_without_badge
    render(NotificationFilterLinkComponent.new(text: 'Requests', filter_item: { type: 'requests' },
                                               selected_filter: { type: 'requests' }))
  end

  # # Preview at http://HOST:PORT/rails/view_components/notification_filter_link_component/without_badge
  def without_badge
    render(NotificationFilterLinkComponent.new(text: 'Requests', filter_item: { type: 'requests' },
                                               selected_filter: { type: 'comments' }))
  end
end
