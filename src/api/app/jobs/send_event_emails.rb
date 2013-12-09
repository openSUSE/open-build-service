class SendEventEmails 

  attr_accessor :event

  def initialize(event)
    self.event = event
  end

  def perform
    users = event.subscribers
    return if users.empty?
    users.each do |u|
      u = User.find_by_id(u)
      raise 'we need valid users' unless u
      EventMailer.event(u, event).deliver
    end
  end
end
