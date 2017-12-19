class CreateProjectLogEntryJob < ApplicationJob
  queue_as :project_log_rotate

  def perform(event_id)
    event = Event::Base.find(event_id)
    # If the ProjectLogEntry was invalid then we still mark the event as logged
    event.update_attributes(project_logged: true)

    ProjectLogEntry.create_from(event)
  end
end
