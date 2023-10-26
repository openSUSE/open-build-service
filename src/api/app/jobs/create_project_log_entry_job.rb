class CreateProjectLogEntryJob < ApplicationJob
  queue_as :project_log_rotate

  def perform(payload, created_at, event_model_name)
    admin = CONFIG['default_admin'] || 'Admin'
    admin = User.find_by(login: admin)
    admin&.run_as { ProjectLogEntry.create_from(payload, created_at, event_model_name) }
  end
end
