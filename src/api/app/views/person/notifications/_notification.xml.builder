builder.notification(id: notification.id) do
  builder.title notification.title
  builder.event_type notification.event_type.split('::').last.underscore
  builder.comment_ notification.event_payload['comment'] if notification.event_payload['comment']
  builder.description notification.event_payload['description'] if notification.event_payload['description']
  builder.state notification.event_payload['state'] if notification.event_payload['state']
  builder.when notification.event_payload['when'] if notification.event_payload['when']
  builder.who notification.event_payload['who'] if notification.event_payload['who']
  builder.request_number notification.event_payload['number'] if notification.event_payload['number']
end
