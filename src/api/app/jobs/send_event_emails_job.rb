class SendEventEmailsJob < ApplicationJob
  queue_as :mailers

  def perform(event_id)
    event = Event::Base.find(event_id)
    subscribers = event.subscribers

    if subscribers.empty?
      event.update_attributes(mails_sent: true)
      return
    end

    begin
      create_rss_notifications(event)
      EventMailer.event(subscribers, event).deliver_now
    rescue StandardError => e
      Airbrake.notify(e, event_id: event.id)
    ensure
      event.update_attributes(mails_sent: true)
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
