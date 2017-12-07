class ProjectLogRotateJob < ApplicationJob
  queue_as :project_log_rotate

  def perform
    # Package and Project events
    event_types = ["Event::BranchCommand",
                   "Event::Build",
                   "Event::CommentForPackage",
                   "Event::Commit",
                   "Event::CreatePackage",
                   "Event::DeletePackage",
                   "Event::ServiceFail",
                   "Event::ServiceSuccess",
                   "Event::UndeletePackage",
                   "Event::UpdatePackage",
                   "Event::Upload",
                   "Event::VersionChange",
                   "Event::CommentForProject",
                   "Event::CreateProject",
                   "Event::DeleteProject",
                   "Event::UndeleteProject",
                   "Event::UpdateProjectConfig",
                   "Event::UpdateProject"]
    oldest_date = 10.days.ago

    # First, skip old events and mark them all as "logged" (even those that
    # don't belong to the event_classes)
    Event::Base.where(project_logged: false).where(["created_at < ?", oldest_date]).update_all(project_logged: true)

    # Create log entries based on the events (but this time, only those in event_classes)
    Event::Base.where(project_logged: false, eventtype: event_types).find_in_batches(batch_size: 10000) do |events_batch|
      events_batch.each do |event|
        entry = ProjectLogEntry.create_from(event)
        event.update_attributes(project_logged: true) if entry.persisted?
      end
    end

    # Clean up old entries
    ProjectLogEntry.clean_older_than oldest_date
  end
end
