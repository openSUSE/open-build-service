class Notification < ApplicationRecord
  belongs_to :subscriber, polymorphic: true
  belongs_to :notifiable, polymorphic: true

  serialize :event_payload, JSON

  def event
    @event ||= event_type.constantize.new(event_payload)
  end
end
