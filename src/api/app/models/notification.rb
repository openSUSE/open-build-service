class Notification < ApplicationRecord
  MAX_RSS_ITEMS_PER_USER = 10
  MAX_RSS_ITEMS_PER_GROUP = 10
  MAX_PER_PAGE = 300
  EVENT_TYPES = %w[Event::CreateReport Event::ReportForRequest Event::ReportForProject Event::ReportForPackage Event::ReportForComment Event::ReportForUser Event::ClearedDecision Event::FavoredDecision
                   Event::AppealCreated].freeze

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
  scope :with_notifiable, -> { where.not(notifiable_id: nil).where.not(notifiable_type: nil) }
  scope :for_incoming_requests, -> { where(notifiable: User.session.incoming_requests(states: BsRequest::VALID_REQUEST_STATES), delivered: false) }
  scope :for_outgoing_requests, -> { where(notifiable: User.session.outgoing_requests(states: BsRequest::VALID_REQUEST_STATES), delivered: false) }
  scope :for_relationships_created, -> { where(event_type: 'Event::RelationshipCreate', delivered: false) }
  scope :for_relationships_deleted, -> { where(event_type: 'Event::RelationshipDelete', delivered: false) }
  scope :for_failed_builds, -> { where(event_type: 'Event::BuildFail', delivered: false) }
  scope :for_reports, -> { where(event_type: EVENT_TYPES, delivered: false) }
  scope :for_workflow_runs, -> { where(event_type: 'Event::WorkflowRunFail', delivered: false) }
  scope :for_appealed_decisions, -> { where(event_type: 'Event::AppealCreated', delivered: false) }
  # We need to refactor this scope, the `case` statement is way too big
  # rubocop:disable Metrics/BlockLength
  # It's not really that big and it's readable enough
  scope :for_notifiable_type, lambda { |type = 'unread'|
    case type
    when 'read'
      read
    when 'comments'
      unread.where(notifiable_type: 'Comment')
    when 'requests'
      unread.where(notifiable_type: 'BsRequest')
    when 'incoming_requests'
      for_incoming_requests
    when 'outgoing_requests'
      for_outgoing_requests
    when 'relationships_created'
      for_relationships_created
    when 'relationships_deleted'
      for_relationships_deleted
    when 'build_failures'
      for_failed_builds
    when 'reports'
      for_reports
    when 'workflow_runs'
      for_workflow_runs
    when 'appealed_decisions'
      for_appealed_decisions
    else
      unread
    end
  }
  # rubocop:enable Metrics/BlockLength
  scope :for_project_name, ->(project_name) { unread.joins(:projects).where(projects: { name: project_name }) }
  scope :for_group_title, ->(group_title) { unread.joins(:groups).where(groups: { title: group_title }) }
  scope :stale, -> { where('created_at < ?', (CONFIG['notifications_lifetime'] ||= 365).days.ago) }

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
