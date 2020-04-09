class Notification < ApplicationRecord
  belongs_to :subscriber, polymorphic: true
  belongs_to :notifiable, polymorphic: true

  scope :with_notifiable, -> { where.not(notifiable_id: nil, notifiable_type: nil) }
  scope :without_notifiable, -> { where(notifiable_id: nil, notifiable_type: nil) }

  scope :for_subscribed_user, lambda { |user|
    where("(subscriber_type = 'User' AND subscriber_id = ?) OR (subscriber_type = 'Group' AND subscriber_id IN (?))",
          user, user.groups.map(&:id))
  }
  scope :not_marked_as_done, -> { where(delivered: false) }
  default_scope -> { order(created_at: :desc) }

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

  def template_name
    event_type.gsub('Event::', '').underscore
  end
end
