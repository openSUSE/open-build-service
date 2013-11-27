class ProjectLogRotate

  def perform
    event_classes = [Event::Package, Event::Project]
    oldest_date = 10.days.ago

    # First, skip old events and mark them all as "logged" (even those that
    # don't belong to the event_classes)
    Event::Base.where(project_logged: false).where(["created_at < ?", oldest_date]).update_all(project_logged: true)

    # Create log entries based on the events (but this time, only those in event_classes)
    event_classes.each do |event_class|
      event_class.where(project_logged: false).find_in_batches batch_size: 10000 do |group|
        processed_ids = []
        group.each do |event|
          entry = ProjectLogEntry.create_from(event)
          # Mark the event as logged if the entry was succesfully created
          processed_ids << event.id if entry.id
        end
        Event::Base.where(id: processed_ids).update_all(project_logged: true)
      end
    end

    # Clean up old entries
    ProjectLogEntry.clean_older_than oldest_date

    true
  end
end

