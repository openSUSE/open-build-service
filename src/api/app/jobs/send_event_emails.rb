class SendEventEmails

  def perform
    Event::Base.where(mails_sent: false).order(:created_at).limit(1000).each do |event|
      event.mails_sent = true
      begin
        event.save!
      rescue ActiveRecord::StaleObjectError
        # if someone else saved it too, better don't continue - we're not alone
        return false
      end
      subscribers = event.subscribers
      next if subscribers.empty?
      EventMailer.event(subscribers, event).deliver_now
    end
    true
  end
end
