class SendEventEmails
  def perform
    Event::Base.where(mails_sent: false).order(:created_at).limit(1000).lock(true).each do |event|
      event.mails_sent = true
      begin
        event.save!
      rescue ActiveRecord::StaleObjectError
        # if someone else saved it too, better don't continue - we're not alone
        return false
      end

      subscriptions = event.subscriptions
      next if subscriptions.empty?

      # 1. Send the emails to the instant_email subscribers
      subscribers_instant_email = subscriptions.select(&:instant_email?).map(&:subscriber)
      EventMailer.event(subscribers_instant_email, event).deliver_now if subscribers_instant_email.any?


      # 2. Create rss notifications for the instant_email subscribers
      subscriptions.select(&:instant_email?).each do |subscription|
        create_rss_notification(event, subscription)
      end

      # 3. Create rss & daily_email notifications for the daily_email subscribers
      subscriptions.select(&:daily_email?).each do |subscription|
        create_daily_email_notification(event, subscription)
        create_rss_notification(event, subscription)
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
