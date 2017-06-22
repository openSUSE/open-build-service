class SendEventEmails
  def perform
    Event::Base.where(mails_sent: false).order(created_at: :asc).limit(1000).each do |event|
      if event.subscribers.empty?
        event.update_attributes(mails_sent: true)
        next
      end

      begin
        event.subscriptions.each do |subscription|
          create_daily_email_notification(event, subscription) if subscription.daily_email?
          create_rss_notification(event, subscription)
        end

        subscribers_instant_email = event.subscriptions.select(&:instant_email?).map(&:subscriber)
        EventMailer.event(subscribers_instant_email, event).deliver_now if subscribers_instant_email.any?
      rescue StandardError => e
        Airbrake.notify(e, { event_id: event.id })
      ensure
        event.update_attributes(mails_sent: true)
      end
    end
  end

  private

  def create_rss_notification(event, subscription)
    Notification::RssFeedItem.create(
      subscriber: subscription.subscriber,
      event_type: event.eventtype,
      event_payload: event.payload,
      subscription_receiver_role: subscription.receiver_role
    )
  end

  def create_daily_email_notification(event, subscription)
    Notification::DailyEmailItem.create(
      subscriber: subscription.subscriber,
      event_type: event.eventtype,
      event_payload: event.payload,
      subscription_receiver_role: subscription.receiver_role
    )
  end
end
