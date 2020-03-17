class Notification < ApplicationRecord
  belongs_to :subscriber, polymorphic: true
  belongs_to :notifiable, polymorphic: true

  serialize :event_payload, JSON

  scope :stale, -> { where('created_at < ?', 3.months.ago) }

  def event
    @event ||= event_type.constantize.new(event_payload)
  end

  def self.cleanup
    Notification.stale.delete_all
  end

  def user_active?
    !subscriber.away?
  end

  def any_user_in_group_active?
    !subscriber.users.recently_seen.empty?
  end
end
