class Notification < ApplicationRecord
  MAX_RSS_ITEMS_PER_USER = 10
  MAX_RSS_ITEMS_PER_GROUP = 10

  belongs_to :subscriber, polymorphic: true, optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  belongs_to :bs_request, -> { where(notifications: { notifiable_type: 'BsRequest' }) }, foreign_key: 'notifiable_id', inverse_of: :notifications, optional: true

  has_many :notified_projects, dependent: :destroy
  has_many :projects, through: :notified_projects
  has_and_belongs_to_many :groups

  serialize :event_payload, coder: JSON

  validates :type, length: { maximum: 255 }

  after_create :track_notification_creation

  after_save :track_notification_delivered, if: :saved_change_to_delivered?

  scope :for_web, -> { where(web: true) }
  scope :for_rss, -> { where(rss: true) }

  # Regarding notification state
  scope :read, -> { where(delivered: true) }
  scope :unread, -> { where(delivered: false) }

  # Regarding notifiable type
  scope :with_notifiable, -> { where.not(notifiable_id: nil).where.not(notifiable_type: nil) }
  scope :for_incoming_requests, ->(user) { where(notifiable: user.incoming_requests(states: BsRequest::VALID_REQUEST_STATES)) }
  scope :for_outgoing_requests, ->(user) { where(notifiable: user.outgoing_requests(states: BsRequest::VALID_REQUEST_STATES)) }
  scope :for_relationships_created, -> { where(event_type: 'Event::RelationshipCreate') }
  scope :for_relationships_deleted, -> { where(event_type: 'Event::RelationshipDelete') }
  scope :for_build_failures, -> { where(event_type: 'Event::BuildFail') }
  scope :for_reports, -> { where(notifiable_type: 'Report') }
  scope :for_workflow_runs, -> { where(notifiable_type: 'WorkflowRun') }
  scope :for_appealed_decisions, -> { where(notifiable_type: 'Decision') }
  scope :for_comments, -> { where(notifiable_type: 'Comment') }
  scope :for_requests, -> { where(notifiable_type: 'BsRequest') }
  scope :for_reviews, -> { where(event_type: 'Event::ReviewWanted') }
  scope :for_member_on_groups, -> { where(notifiable_type: 'Group') }

  scope :for_project_name, ->(project_name) { joins(:projects).where(projects: { name: project_name }) }
  scope :for_group_title, ->(group_title) { joins(:groups).where(groups: { title: group_title }) }
  scope :for_request_state, ->(request_state) { joins(:bs_request).where(bs_request: { state: request_state }) }
  scope :stale, -> { where(created_at: ...(CONFIG['notifications_lifetime'] ||= 365).days.ago) }

  paginates_per 30
  max_paginates_per 300

  def event
    @event ||= event_type.constantize.new(event_payload)
  end

  def user_active?
    !subscriber.away?
  end

  def any_user_in_group_active?
    subscriber.users.seen_since(3.months.ago).any?
  end

  def template_name
    event_type.gsub('Event::', '').underscore
  end

  def read?
    delivered?
  end

  def unread?
    !read?
  end

  def unread_date
    last_seen_at || created_at
  end

  # FIXME: user_login is the old name in the Notification.event_payload. We should drop this in 365 days...
  def accused
    User.find_by(login: event_payload['accused']) || User.find_by(login: event_payload['user_login'])
  end

  private

  def track_notification_creation
    RabbitmqBus.send_to_bus('metrics',
                            "notification.create,notifiable_type=#{notifiable_type},web=#{web},rss=#{rss} value=1")
  end

  # This is only called when the request come from the API. The UI performs 'update_all' that does not trigger callbacks.
  # This metrics complements the same metrics tracked in Webui::Users::NotificationsController#send_notifications_information_rabbitmq
  def track_notification_delivered
    RabbitmqBus.send_to_bus('metrics',
                            "notification,action=#{delivered ? 'read' : 'unread'} value=1")
  end
end

# == Schema Information
#
# Table name: notifications
#
#  id                         :bigint           not null, primary key
#  bs_request_oldstate        :string(255)
#  bs_request_state           :string(255)
#  delivered                  :boolean          default(FALSE), indexed
#  event_payload              :text(16777215)   not null
#  event_type                 :string(255)      not null, indexed
#  last_seen_at               :datetime
#  notifiable_type            :string(255)      indexed => [notifiable_id]
#  rss                        :boolean          default(FALSE), indexed
#  subscriber_type            :string(255)      indexed => [subscriber_id]
#  subscription_receiver_role :string(255)      not null
#  title                      :string(255)
#  type                       :string(255)      indexed
#  web                        :boolean          default(FALSE), indexed
#  created_at                 :datetime         not null, indexed
#  updated_at                 :datetime         not null
#  notifiable_id              :integer          indexed => [notifiable_type]
#  subscriber_id              :integer          indexed => [subscriber_type]
#
# Indexes
#
#  index_notifications_on_created_at                         (created_at)
#  index_notifications_on_delivered                          (delivered)
#  index_notifications_on_event_type                         (event_type)
#  index_notifications_on_notifiable_type_and_notifiable_id  (notifiable_type,notifiable_id)
#  index_notifications_on_rss                                (rss)
#  index_notifications_on_subscriber_type_and_subscriber_id  (subscriber_type,subscriber_id)
#  index_notifications_on_type                               (type)
#  index_notifications_on_web                                (web)
#
