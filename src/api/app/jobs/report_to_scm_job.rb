# We don't properly capitalize SCM in the class name since CreateJob is doing `CLASS_NAME.to_s.camelize.safe_constantize`
class ReportToScmJob < CreateJob
  ALLOWED_EVENTS = ['Event::BuildFail', 'Event::BuildSuccess'].freeze

  queue_as :scm

  def perform(event_id)
    return false unless perform_job?(event_id)

    matched_event_subscription.each do |event_subscription|
      SCMStatusReporter.new(@event.payload,
                            event_subscription.payload,
                            event_subscription.token.scm_token,
                            event_subscription.eventtype).call
    end
    true
  end

  private

  def perform_job?(event_id)
    @event = Event::Base.find(event_id)
    return false unless @event.undone_jobs.positive?

    @event_type = @event.eventtype
    return false unless ALLOWED_EVENTS.include?(@event_type)

    @event_package = Package.find_by_project_and_name(@event.payload['project'], Package.striping_multibuild_suffix(@event.payload['package']))
    return false if @event_package.blank?

    true
  end

  def matched_event_subscription
    EventSubscriptionsFinder.new
                            .for_scm_channel_with_token(event_type: @event_type, event_package: @event_package)
                            .select do |event_subscription|
      Workflows::Filter.new(filters: event_subscription.payload['workflow_filters']).match?(@event)
    end
  end
end
