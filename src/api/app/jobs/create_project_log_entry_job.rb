class CreateProjectLogEntryJob < ApplicationJob
  queue_as :project_log_rotate

  def perform(payload, created_at, event_model_name)
    ProjectLogEntry.create_from(payload, created_at, event_model_name)
  end
end
