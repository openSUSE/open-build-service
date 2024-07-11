class NotificationWorkflowRun < Notification
  def description
    ''
  end

  def excerpt
    "In repository #{notifiable.repository_full_name}"
  end

  def avatar_objects
    [Token.find(event_payload['token_id'])&.executor].compact
  end

  def link_text
    'Workflow Run'
  end

  def link_path
    return if notifiable.blank?

    Rails.application.routes.url_helpers.token_workflow_run_path(notifiable.token, notifiable, notification_id: id)
  end
end
