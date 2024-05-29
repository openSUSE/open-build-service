class NotificationWorkflowRun < Notification
  # TODO: rename to title once we get rid of Notification#title
  def summary
    'Workflow Run'
  end

  def description
    ''
  end

  def excerpt
    "In repository #{notifiable.repository_full_name}"
  end

  def involved_users
    [Token.find(event_payload['token_id'])&.executor].compact
  end
end
