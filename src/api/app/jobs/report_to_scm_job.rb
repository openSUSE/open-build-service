class ReportToSCMJob < ApplicationJob
  include EventUndoneJobsCallback

  ALLOWED_EVENTS = ['Event::BuildFail', 'Event::BuildSuccess', 'Event::RequestStatechange'].freeze

  # Transient errors that are worth retrying: SCM-side 5xx, rate limits, network glitches and auth failures.
  # 4xx config errors, and SSL problems are not retried.
  RETRYABLE_EXCEPTIONS = [
    Gitlab::Error::BadGateway,
    Gitlab::Error::ConnectionTimedOut,
    Gitlab::Error::InternalServerError,
    Gitlab::Error::ServiceUnavailable,
    Gitlab::Error::Unauthorized,
    Octokit::InternalServerError,
    Octokit::BadGateway,
    Octokit::ServiceUnavailable,
    Octokit::ServerError,
    Octokit::Unauthorized,
    Faraday::ConnectionFailed,
    Faraday::TimeoutError
  ].freeze
  # Transient errors that are worth retrying, but with longer wait times
  RETRYABLE_LONG_WAIT_EXCEPTIONS = [Gitlab::Error::TooManyRequests, Octokit::TooManyRequests].freeze

  # Progressive time before retrying the job in case of retryable exceptions
  RETRY_WAIT_TIMES = { 1 => 0, 2 => 1.minute, 3 => 2.minutes, 4 => 5.minutes, 5 => 10.minutes }.freeze
  retry_on(*RETRYABLE_EXCEPTIONS, wait: ->(executions) { RETRY_WAIT_TIMES.fetch(executions) }, attempts: 6)

  RETRY_LONG_WAIT_TIMES = { 1 => 1.minute, 2 => 5.minutes, 3 => 10.minutes, 4 => 15.minutes, 5 => 30.minutes }.freeze
  retry_on(*RETRYABLE_LONG_WAIT_EXCEPTIONS, wait: ->(executions) { RETRY_LONG_WAIT_TIMES.fetch(executions) }, attempts: 6)

  queue_as :scm

  def perform(event_id: nil, workflow_run: nil, event_type: nil, initial_report: false, event_payload: nil)
    if event_id
      report_event(event_id)
    else
      report_direct(workflow_run, event_type: event_type, initial_report: initial_report, event_payload: event_payload)
    end
  end

  private

  def report_event(event_id)
    event = Event::Base.find(event_id)
    return unless event
    return unless event.undone_jobs.positive?
    return unless ALLOWED_EVENTS.include?(event.eventtype)
    return unless event.event_object

    matched_event_subscription(event: event).each do |event_subscription|
      SCMStatusReporter.new(event_payload: event.payload,
                            event_subscription_payload: event_subscription.workflow_run&.payload,
                            scm_token: event_subscription.token.scm_token,
                            workflow_run: event_subscription.workflow_run,
                            event_type: event_subscription.eventtype).call
    end
  end

  def report_direct(workflow_run, event_type:, initial_report:, event_payload:)
    SCMStatusReporter.new(event_payload: event_payload || workflow_run.payload,
                          event_subscription_payload: workflow_run.payload,
                          scm_token: workflow_run.token.scm_token,
                          workflow_run: workflow_run,
                          event_type: event_type,
                          initial_report: initial_report).call
  end

  def matched_event_subscription(event:)
    subscriptions = EventSubscription.joins(:token).where(channel: :scm).where(eventtype: event.eventtype).where(token: { enabled: true })

    if event.eventtype == 'Event::RequestStatechange'
      subscriptions.where(bs_request: event.event_object)
    else
      subscriptions.where(package: event.event_object)
    end
  end
end
