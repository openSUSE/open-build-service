class NotificationsFinder
  EVENT_TYPES = ['Event::CreateReport', 'Event::ReportForRequest', 'Event::ReportForProject', 'Event::ReportForPackage', 'Event::ReportForComment',
                 'Event::ReportForUser', 'Event::ClearedDecision', 'Event::FavoredDecision', 'Event::AppealCreated'].freeze

  def initialize(relation = Notification.all)
    @relation = if Flipper.enabled?(:content_moderation, User.session)
                  relation.order(created_at: :desc)
                else
                  # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
                  relation.where.not(event_type: EVENT_TYPES).order(created_at: :desc)
                end
  end

  def read
    @relation.where(delivered: true)
  end

  def unread
    @relation.where(delivered: false)
  end

  def with_notifiable
    @relation.where.not(notifiable_id: nil).where.not(notifiable_type: nil)
  end

  def without_notifiable
    @relation.where(notifiable_id: nil, notifiable_type: nil)
  end

  def for_incoming_requests
    @relation.where(notifiable: User.session.incoming_requests(all_states: true), delivered: false)
  end

  def for_outgoing_requests
    @relation.where(notifiable: User.session.outgoing_requests(all_states: true), delivered: false)
  end

  def for_relationships_created
    @relation.where(event_type: 'Event::RelationshipCreate', delivered: false)
  end

  def for_relationships_deleted
    @relation.where(event_type: 'Event::RelationshipDelete', delivered: false)
  end

  def for_failed_builds
    @relation.where(event_type: 'Event::BuildFail', delivered: false)
  end

  def for_reports
    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    @relation.where(event_type: EVENT_TYPES, delivered: false)
  end

  def for_workflow_runs
    @relation.where(event_type: 'Event::WorkflowRunFail', delivered: false)
  end

  def for_appealed_decisions
    @relation.where(event_type: 'Event::AppealCreated', delivered: false)
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # We need to refactor this method, the `case` statement is way too big
  def for_notifiable_type(type = 'unread')
    notifications = self.class.new(with_notifiable)

    case type
    when 'read'
      notifications.read
    when 'comments'
      notifications.unread.where(notifiable_type: 'Comment')
    when 'requests'
      notifications.unread.where(notifiable_type: 'BsRequest')
    when 'incoming_requests'
      notifications.for_incoming_requests
    when 'outgoing_requests'
      notifications.for_outgoing_requests
    when 'relationships_created'
      notifications.for_relationships_created
    when 'relationships_deleted'
      notifications.for_relationships_deleted
    when 'build_failures'
      notifications.for_failed_builds
    when 'reports'
      notifications.for_reports
    when 'workflow_runs'
      notifications.for_workflow_runs
    when 'appealed_decisions'
      notifications.for_appealed_decisions
    else
      notifications.unread
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def for_project_name(project_name)
    unread.joins(:projects).where(projects: { name: project_name })
  end

  def for_group_title(group_title)
    unread.joins(:groups).where(groups: { title: group_title })
  end

  def stale
    @relation.where('created_at < ?', notifications_lifetime.days.ago)
  end

  private

  def notifications_lifetime
    CONFIG['notifications_lifetime'] ||= 365
  end
end
