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

      next if event.subscribers.empty?

      subscribers = event.subscribers.select { |subscriber| subscriber.digest_email_enabled == false }
      digest_subscribers = event.subscribers.select { |subscriber| subscriber.digest_email_enabled == true }

      # Send an email to the subscribers with digest_email_enabled == false
      if subscribers.any?
        EventMailer.event(subscribers, event).deliver_now
      end

      # Add to a digest email for the subscribers with digest_email_enabled == true
      digest_subscribers.each do |subscriber|
        digest_email =
          if subscriber.is_a? User
            DigestEmail.find_or_create_by(user: subscriber, sent_at: nil)
          elsif subscriber.is_a? Group
            DigestEmail.find_or_create_by(group: subscriber, sent_at: nil)
          end

        digest_email.events << event
      end
    end
    true
  end
end
