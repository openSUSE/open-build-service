class ReportToSCMJob < CreateJob
  ALLOWED_EVENTS = ['Event::BuildFail', 'Event::BuildSuccess', 'Event::RequestStatechange'].freeze

  # Raised when the SCM API returns a transient error worth retrying.
  # Kept here (not in SCMExceptionHandler) so the retry logic is entirely
  # job-scoped and vendor reporters stay safe to call from threads too.
  class RetryableError < StandardError; end

  # Wait schedule keyed by attempt number (attempt 1 = immediate, then backoff).
  RETRY_WAIT_TIMES = { 1 => 0, 2 => 1.minute, 3 => 2.minutes, 4 => 5.minutes, 5 => 10.minutes, 6 => 15.minutes }.freeze

  MAX_ATTEMPTS = RETRY_WAIT_TIMES.size + 1

  queue_as :scm

  # Re-raise RetryableError so it escapes rescue_from(StandardError) in CreateJob
  # and reaches delayed_job, which then calls reschedule_at for the next attempt time.
  rescue_from RetryableError do |e|
    raise e
  end

  def max_attempts
    MAX_ATTEMPTS
  end

  def reschedule_at(current_time, attempts)
    current_time + RETRY_WAIT_TIMES.fetch(attempts)
  end

  # Called by delayed_job when max_attempts is exhausted.
  # Keeps undone_jobs balanced (after_perform never fired) and records a final failure.
  def failure(_job = nil)
    event = Event::Base.find_by(id: arguments.first)
    return unless event

    event.with_lock { event.mark_job_done! }
    matched_event_subscription(event: event).each do |subscription|
      next if subscription.workflow_run.blank?
      
      subscription.workflow_run.save_scm_report_failure('Failed to report back to SCM: all retries exhausted', {})
    end
  end

  def perform(event_id)
    event = Event::Base.find(event_id)
    return unless event
    return unless event.undone_jobs.positive?
    return unless ALLOWED_EVENTS.include?(event.eventtype)
    return unless event.event_object

    matched_event_subscription(event: event).each do |event_subscription|
      begin
        SCMStatusReporter.new(event_payload: event.payload,
                              event_subscription_payload: event_subscription.workflow_run&.payload,
                              scm_token: event_subscription.token.scm_token,
                              workflow_run: event_subscription.workflow_run,
                              event_type: event_subscription.eventtype).call
      rescue *SCMExceptionHandler::RETRYABLE_EXCEPTIONS => e
        raise RetryableError, e.message
      end
    end
  end

  private

  def matched_event_subscription(event:)
    subscriptions = EventSubscription.joins(:token).where(channel: :scm).where(eventtype: event.eventtype).where(token: { enabled: true })

    if event.eventtype == 'Event::RequestStatechange'
      subscriptions.where(bs_request: event.event_object)
    else
      subscriptions.where(package: event.event_object)
    end
  end
end
