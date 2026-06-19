module EventUndoneJobsCallback

  extend ActiveSupport::Concern

  included do
    attr_reader :event_id

    after_perform do |job|
      next unless job.event_id

      event = Event::Base.find(job.event_id)

      event.with_lock do
        event.mark_job_done!
      end
    end
  end
end
