class SendEventEmails
  # we don't need this outside of the migration - but we need to be able
  # to load old jobs from the database (and mark their events) before deleting
  # (see 20151030130011_mark_events)
  attr_accessor :event

  def perform
    Event::Base.where(mails_sent: false).order(created_at: :asc).limit(1000).each do |event|
      subscribers = event.subscribers
      next if subscribers.empty?
      create_rss_notifications(event)
      EventMailer.event(subscribers, event).deliver_now
      event.update_attributes(mails_sent: true)
    end
    true
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
