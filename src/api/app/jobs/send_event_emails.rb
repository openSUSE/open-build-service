class SendEventEmails 

  attr_accessor :event

  def initialize(event)
    self.event = event
  end

  def perform
    users = event.subscribers
    return if users.empty?
    EventMailer.event(User.where(id: users), event).deliver
  end
end
