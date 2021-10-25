xml.notifications(count: @notifications_total) do
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> 644fec08a1 (Add pagination information to the Notifications API endpoint)
=======
>>>>>>> dd863c268e193e2460851b3ae507e0a2b9772d1c
  if @notifications_total.positive?
    xml.total_pages @notifications.total_pages
    xml.current_page @notifications.current_page
  end
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> bdb45c668c (Create a read-only api for notifications)
=======
>>>>>>> 644fec08a1 (Add pagination information to the Notifications API endpoint)
=======
>>>>>>> dd863c268e193e2460851b3ae507e0a2b9772d1c
  render partial: 'person/notifications/notification', collection: @notifications, locals: { builder: xml }
end
