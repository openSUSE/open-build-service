xml.notifications(count: @notifications_total) do
  render partial: 'person/notifications/notification', collection: @notifications, locals: { builder: xml }
end
