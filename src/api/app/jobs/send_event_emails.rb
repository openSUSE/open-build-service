class SendEventEmails < CreateJob

  attr_accessor :event

  def perform
    subscribers = event.subscribers
    return if subscribers.empty?
    EventMailer.event(subscribers, event).deliver_later
  end
end
