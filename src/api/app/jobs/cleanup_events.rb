class CleanupEvents
  def perform
    Event::Base.where(project_logged: true, queued: true, undone_jobs: 0).delete_all
  end
end
