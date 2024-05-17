builder.notification(id: notification.id) do
  builder.title notification.title
  builder.type notification.event_type.split('::').last.underscore
  builder.time notification.created_at
  if (state = if notification.notifiable_type == 'BsRequest'
                notification.notifiable.state
              elsif notification.notifiable_type == 'WorkflowRun'
                notification.notifiable.status
              end)
    builder.state state
  end
  builder.who notification.event_payload['who'] if notification.event_payload['who']
  if (description = NotificationActionDescriptionComponent.new(notification).description_text(render_text: true)).present?
    builder.description description
  end
  if (excerpt = NotificationExcerptComponent.new(notification).call).present?
    builder.excerpt excerpt
  end
  builder.request_number notification.event_payload['number'] if notification.event_payload['number']
end
