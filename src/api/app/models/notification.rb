class Notification < ApplicationRecord
  belongs_to :subscriber, polymorphic: true

  serialize :event_payload, JSON

  def event
    @event ||= event_type.constantize.new(event_payload)
  end
end
