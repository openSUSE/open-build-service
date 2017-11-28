class ProjectLogRotateJob < ApplicationJob
  queue_as :project_log_rotate

  def perform(event_id)
    event = Event::Base.find(event_id)
    entry = ProjectLogEntry.create_from(event)
    event.update_attributes(project_logged: true) if entry.persisted?
  end
end
