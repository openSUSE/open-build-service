class SendEventEmails
  # we don't need this outside of the migration - but we need to be able
  # to load old jobs from the database (and mark their events) before deleting
  # (see 20151030130011_mark_events)
  attr_accessor :event

  def perform
    Event::Base.where(mails_sent: false).order(:created_at).limit(1000).lock(true).each do |event|
      event.mails_sent = true
      begin
        event.save!
      rescue ActiveRecord::StaleObjectError
        # if someone else saved it too, better don't continue - we're not alone
        return false
      end

      next if event.subscriptions.empty?

      subscriptions = event.subscriptions.reject(&:digest_email_enabled?)
      digest_subscriptions = event.subscriptions.select(&:digest_email_enabled?)

      # Send an email to the subscribers with digest_email_enabled == false
      if subscriptions.any?
        EventMailer.email_for_event(subscriptions.map(&:subscriber), event).deliver_now
      end

      # Add to a digest email for the subscribers with digest_email_enabled == true
      digest_subscriptions.each do |subscription|
        digest_email = DigestEmail.find_or_create_by(event_subscription: subscription, sent_at: nil)
        digest_email.events << event
      end
    end
  end
end
