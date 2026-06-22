module EventUndoneJobsCallback

  extend ActiveSupport::Concern

  included do
    after_perform do |job|
      event_id = job.arguments.first[:event_id]
      next unless event_id

      event = Event::Base.find(event_id)

      event.with_lock do
        event.mark_job_done!
      end
    end
  end
end
