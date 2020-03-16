class Notification < ApplicationRecord
  belongs_to :subscriber, polymorphic: true
  belongs_to :notifiable, polymorphic: true

  serialize :event_payload, JSON

  scope :stale, -> { where('created_at < ?', 3.months.ago) }

  # apply only to users
  # by notification creation, check if the user logged in the last 3 months and if not,
  # don't create it

  # apply only to groups
  # by notification creation if any user in the group logged in in the last 3 months and if not,
  # don't create it
  validate :user_active?, if: -> { subscriber.is_a?(User) }
  validate :any_user_in_group_active?, if: -> { subscriber.is_a?(Group) }

  def event
    @event ||= event_type.constantize.new(event_payload)
  end

  def self.cleanup
    Notification.stale.delete_all
  end

  private

  def user_active?
    errors.add(:subscriber, 'subscriber not active') if subscriber && subscriber.away?
  end

  def any_user_in_group_active?
    return true if subscriber.users.recently_seen.empty?
    errors.add(:subscriber, 'subscribers aren\'t active')
  end
end
