xml.notifications(count: @notifications_count) do
  if @notifications_count.positive?
    xml.total_pages @paged_notifications.total_pages
    xml.current_page @paged_notifications.current_page
  end
  render partial: 'person/notifications/notification', collection: @paged_notifications, locals: { builder: xml }
end
