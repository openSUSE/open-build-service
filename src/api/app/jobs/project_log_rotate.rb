class ProjectLogRotate

  def perform
    event_classes = [Event::Package, Event::Project]
    oldest_date = 10.days.ago

    # Create log entries based on the events
    event_classes.each do |event_class|
      unprocessed_events = event_class.where(project_logged: false)
      # First, skip old events and mark them all as "logged"
      unprocessed_events.where(["created_at < ?", oldest_date]).update_all(project_logged: true)
      # Then, process the rest (this will query project_logged again)
      unprocessed_events.find_in_batches batch_size: 10000 do |group|
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

