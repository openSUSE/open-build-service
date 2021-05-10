class ReportToScmJob < CreateJob
  # We don't properly capitalize SCM in the class name since CreateJob is doing `CLASS_NAME.to_s.camelize.safe_constantize`
  queue_as :scm

  def perform(event_id)
    event = Event::Base.find(event_id)
    return true unless event

    EventSubscription.joins('INNER JOIN events ON event_subscriptions.eventtype = events.eventtype AND event_subscriptions.package_id = events.package_id')
                     .where(events: { eventtype: ['Event::BuildFail', 'Event::BuildSuccess'], id: event_id }, channel: :scm)
                     .where(Event::Base.arel_table[:undone_jobs].gt(0))
                     .where.not(token_id: nil)
                     .order('events.created_at ASC').each do |event_subscription|
      SCMStatusReporter.new(event_subscription.payload, event_subscription.token.scm_token, event_subscription.eventtype).call
    rescue StandardError => e
      Airbrake.notify(e, event_id: event_id)
      if event.undone_jobs.positive?
        event.undone_jobs -= 1
        event.save!
      end
    end

    true
  end
end
