class SendEventEmails < CreateJob

  attr_accessor :event

  def perform
    users = event.subscribers
    return if users.empty?
    EventMailer.event(User.where(id: users).order(:id), event).deliver
  end
end
