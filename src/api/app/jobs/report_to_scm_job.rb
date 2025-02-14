class ReportToSCMJob < CreateJob
  ALLOWED_EVENTS = ['Event::BuildFail', 'Event::BuildSuccess', 'Event::RequestStatechange'].freeze

  queue_as :scm

  def perform(event_id)
    event = Event::Base.find(event_id)
    return unless event
    return unless event.undone_jobs.positive?
    return unless ALLOWED_EVENTS.include?(event.eventtype)
    return unless event.event_object

    matched_event_subscription(event: event).each do |event_subscription|
      SCMStatusReporter.new(event_payload: event.payload,
                            event_subscription_payload: event_subscription.payload,
                            scm_token: event_subscription.token.scm_token,
                            workflow_run: event_subscription.workflow_run,
                            event_type: event_subscription.eventtype).call
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
