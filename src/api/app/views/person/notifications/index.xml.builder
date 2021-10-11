xml.notifications(count: @notifications_total) do
  if @notifications_total.positive?
    xml.total_pages @notifications.total_pages
    xml.current_page @notifications.current_page
  end
  render partial: 'person/notifications/notification', collection: @notifications, locals: { builder: xml }
end
