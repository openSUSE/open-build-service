# TODO: Rename this to something more appropriate like "ProcessEvents"
class SendEventEmails
  # we don't need this outside of the migration - but we need to be able
  # to load old jobs from the database (and mark their events) before deleting
  # (see 20151030130011_mark_events)
  attr_accessor :event

  def perform
    Event::Base.where(mails_sent: false).order(:created_at).limit(1000).each do |event|
      subscribers = event.subscribers
      next if subscribers.empty?

      event.mails_sent = true
      event.save

      EventMailer.event(subscribers, event).deliver_now

      create_rss_notifications(event)
      event.create_project_log_entry if event.needs_logging?
    end
  end

  private

  def create_rss_notifications(event)
    event.subscriptions.each do |subscription|
      Notification::RssFeedItem.create(
        subscriber: subscription.subscriber,
        event_type: event.eventtype,
        event_payload: event.payload,
        subscription_receiver_role: subscription.receiver_role
      )
    end
  end
end
