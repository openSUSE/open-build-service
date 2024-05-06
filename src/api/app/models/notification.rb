class Notification < ApplicationRecord
  MAX_RSS_ITEMS_PER_USER = 10
  MAX_RSS_ITEMS_PER_GROUP = 10
  MAX_PER_PAGE = 300

  EVENT_TYPES = ['Event::CreateReport', 'Event::ReportForRequest', 'Event::ReportForProject', 'Event::ReportForPackage', 'Event::ReportForComment',
                 'Event::ReportForUser', 'Event::ClearedDecision', 'Event::FavoredDecision', 'Event::AppealCreated'].freeze

  belongs_to :subscriber, polymorphic: true, optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  has_many :notified_projects, dependent: :destroy
  has_many :projects, through: :notified_projects
  has_and_belongs_to_many :groups

  serialize :event_payload, JSON

  after_create :track_notification_creation

  after_save :track_notification_delivered, if: :saved_change_to_delivered?

  scope :for_web, -> { where(web: true) }
  scope :for_rss, -> { where(rss: true) }

  scope :read, -> { where(delivered: true) }
  scope :unread, -> { where(delivered: false) }

  scope :comments, -> { where(notifiable_type: 'Comment') }
  scope :requests, -> { where(notifiable_type: 'BsRequest') }
  scope :with_notifiable, -> { where.not(notifiable_id: nil).where.not(notifiable_type: nil) }
  scope :without_notifiable, -> { where(notifiable_id: nil, notifiable_type: nil) }
  scope :incoming_requests, ->(user) { where(notifiable: user.incoming_requests(states: BsRequest::VALID_REQUEST_STATES)) }
  scope :outgoing_requests, ->(user) { where(notifiable: user.outgoing_requests(states: BsRequest::VALID_REQUEST_STATES)) }
  scope :relationships_created, -> { where(event_type: 'Event::RelationshipCreate') }
  scope :relationships_deleted, -> { where(event_type: 'Event::RelationshipDelete') }
  scope :build_failures, -> { where(event_type: 'Event::BuildFail') }
  # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
  scope :reports, -> { where(event_type: EVENT_TYPES) }
  scope :workflow_runs, -> { where(event_type: 'Event::WorkflowRunFail') }
  scope :appealed_decisions, -> { where(event_type: 'Event::AppealCreated') }
  scope :for_project, ->(name) { joins(:projects).where(projects: { name: name }) }
  scope :for_group, ->(name) { joins(:groups).where(groups: { title: name }) }

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

  def event_user
    User.find_by_login(event_payload['user_login']) if event_payload['user_login']
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
#  delivered                  :boolean          default(FALSE)
#  event_payload              :text(65535)      not null
#  event_type                 :string(255)      not null
#  last_seen_at               :datetime
#  notifiable_type            :string(255)      indexed => [notifiable_id]
#  rss                        :boolean          default(FALSE)
#  subscriber_type            :string(255)      indexed => [subscriber_id]
#  subscription_receiver_role :string(255)      not null
#  title                      :string(255)
#  web                        :boolean          default(FALSE)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  notifiable_id              :integer          indexed => [notifiable_type]
#  subscriber_id              :integer          indexed => [subscriber_type]
#
# Indexes
#
#  index_notifications_on_notifiable_type_and_notifiable_id  (notifiable_type,notifiable_id)
#  index_notifications_on_subscriber_type_and_subscriber_id  (subscriber_type,subscriber_id)
#
