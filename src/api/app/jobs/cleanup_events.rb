class CleanupEvents < ApplicationJob
  def perform
    Event::Base.transaction do
      Event::Base.where(project_logged: true, mails_sent: true, undone_jobs: 0).lock(true).delete_all
    end

    event_types = Event::PROJECT_CLASSES | Event::PACKAGE_CLASSES
    Event::Base.where(project_logged: false, mails_sent: true, undone_jobs: 0).where.not(eventtype: event_types).delete_all
  end
end
