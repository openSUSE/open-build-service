class Notification < ApplicationRecord
  belongs_to :subscriber, polymorphic: true

  serialize :event_payload, JSON

  scope :stale, -> { where('created_at < ?', 3.months.ago) }

  def event
    @event ||= event_type.constantize.new(event_payload)
  end

  def self.cleanup
    Notification.stale.delete_all
  end
end
