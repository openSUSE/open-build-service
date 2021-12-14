xml.notifications(count: @notifications_count) do
  if @notifications_count.positive?
    xml.total_pages @notifications.total_pages
    xml.current_page @notifications.current_page
  end
  render partial: 'person/notifications/notification', collection: @notifications, locals: { builder: xml }
end
