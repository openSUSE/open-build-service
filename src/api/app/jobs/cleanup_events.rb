class CleanupEvents
  def perform
    Event::Base.where(project_logged: true, queued: true).delete_all
  end
end
