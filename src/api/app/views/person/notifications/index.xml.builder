xml.notifications(count: @notifications_total) do
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> 644fec08a1 (Add pagination information to the Notifications API endpoint)
  if @notifications_total.positive?
    xml.total_pages @notifications.total_pages
    xml.current_page @notifications.current_page
  end
<<<<<<< HEAD
=======
>>>>>>> bdb45c668c (Create a read-only api for notifications)
=======
>>>>>>> 644fec08a1 (Add pagination information to the Notifications API endpoint)
  render partial: 'person/notifications/notification', collection: @notifications, locals: { builder: xml }
end
