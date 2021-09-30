xml.notifications(count: @notifications_total) do
<<<<<<< HEAD
  if @notifications_total.positive?
    xml.total_pages @notifications.total_pages
    xml.current_page @notifications.current_page
  end
=======
>>>>>>> bdb45c668c (Create a read-only api for notifications)
  render partial: 'person/notifications/notification', collection: @notifications, locals: { builder: xml }
end
