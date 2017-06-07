class CleanupEvents < ApplicationJob
  def perform
    Event::Base.transaction do
      events_to_be_deleted.lock(true).delete_all
    end
  end

  private

  def events_to_be_deleted
    # delete_all will not work with this query so we need to find again by id
    events_to_be_deleted_array =
      Event::Base.left_outer_joins(:digest_emails)
        .select('events.*, MIN(digest_emails.email_sent) AS has_all_digest_emails_sent')
        .where(project_logged: true, queued: true, undone_jobs: 0)
        .group('events.id')
        .having('has_all_digest_emails_sent = 1 OR has_all_digest_emails_sent IS NULL')

    event_ids = events_to_be_deleted_array.map(&:id)

    Event::Base.where(id: event_ids)
  end
end
