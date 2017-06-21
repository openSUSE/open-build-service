class CreateJob
  def initialize(event)
    self.event = event
  end

  def after(job)
    event = job.payload_object.event
    # in test suite the undone_jobs are 0 as the delayed jobs are not delayed
    event.with_lock do
      event.undone_jobs -= 1
      event.save!
    end
  end

  def error(job, exception)
    if Rails.env.test?
      # make debug output useful in test suite, not just showing backtrace to Airbrake
      Rails.logger.debug "ERROR: #{exception.inspect}: #{exception.backtrace}"
      puts exception.inspect, exception.backtrace
      return
    end
    Airbrake.notify(exception, {failed_job: job.inspect})
  end
end
