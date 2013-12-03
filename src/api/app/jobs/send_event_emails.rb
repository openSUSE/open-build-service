class SendEventEmails 

  attr_accessor :event

  def initialize(event)
    self.event = event
  end

  def perform
    users = event.subscribers
    return if users.empty?
    users.each do |u|
      EventMailer.event(User.find(u), event).deliver
    end
  end
end
