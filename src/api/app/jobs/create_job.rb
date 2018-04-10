# frozen_string_literal: true
class CreateJob < ApplicationJob
  def perform(_event_id)
    raise NotImplementedError
  end

  after_perform do |job|
    event_id = job.arguments.first
    event = Event::Base.find(event_id)

    # in test suite the undone_jobs are 0 as the delayed jobs are not delayed
    event.with_lock do
      event.undone_jobs -= 1
      event.save!
    end
  end

  rescue_from(StandardError) do |exception|
    if Rails.env.test?
      # make debug output useful in test suite, not just showing backtrace to Airbrake
      Rails.logger.debug "ERROR: #{exception.inspect}: #{exception.backtrace}"
      puts exception.inspect, exception.backtrace
    end
    Airbrake.notify(exception, failed_job: job_id)
  end
end
