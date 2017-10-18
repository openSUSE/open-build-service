class CleanupEvents < ApplicationJob
  def perform
    Event::Base.transaction do
      Event::Base.where(project_logged: true, mails_sent: true, undone_jobs: 0).lock(true).delete_all
    end
  end
end
