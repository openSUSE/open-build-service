class Notification < ApplicationRecord
  belongs_to :subscriber, polymorphic: true
  belongs_to :notifiable, polymorphic: true

  has_many :notified_projects, dependent: :destroy
  has_many :projects, through: :notified_projects

  serialize :event_payload, JSON

  def event
    @event ||= event_type.constantize.new(event_payload)
  end

  def self.cleanup
    NotificationsFinder.new.stale.delete_all
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

  def unread?
    !delivered?
  end
end
