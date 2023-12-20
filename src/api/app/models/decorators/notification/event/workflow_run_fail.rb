class Decorators::Notification::Event::WorkflowRunFail < Decorators::Notification::Common
  def description_text
    # It's actually empty, no text is rendered
  end

  def notifiable_link_text(_helpers)
    'Workflow Run'
  end
end
