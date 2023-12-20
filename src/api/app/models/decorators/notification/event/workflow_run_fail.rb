class Decorators::Notification::Event::WorkflowRunFail < Decorators::Notification::Common
  def description_text
    # It's actually empty, no text is rendered
  end

  def notifiable_link_text(_helpers)
    'Workflow Run'
  end

  def notifiable_link_path
    Rails.application.routes.url_helpers.token_workflow_run_path(notification.notifiable.token, notification.notifiable)
  end
end
