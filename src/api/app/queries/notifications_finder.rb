class NotificationsFinder
  NOTIFIABLE_TYPE_MAP = {
    'read' => ->(notifications) { notifications.read },
    'comments' => ->(notifications) { notifications.unread.where(notifiable_type: 'Comment') },
    'requests' => ->(notifications) { notifications.unread.where(notifiable_type: 'BsRequest') },
    'incoming_requests' => ->(notifications) { notifications.for_incoming_requests },
    'outgoing_requests' => ->(notifications) { notifications.for_outgoing_requests },
    'relationships_created' => ->(notifications) { notifications.for_relationships_created },
    'relationships_deleted' => ->(notifications) { notifications.for_relationships_deleted },
    'build_failures' => ->(notifications) { notifications.for_failed_builds },
    'reports' => ->(notifications) { notifications.for_reports },
    'workflow_runs' => ->(notifications) { notifications.for_workflow_runs },
    'appealed_decisions' => ->(notifications) { notifications.for_appealed_decisions },
    'unread' => ->(notifications) { notifications.unread },
    nil => ->(notifications) { notifications.unread }
  }.freeze

  def initialize(relation = Notification.all)
    @relation = if Flipper.enabled?(:content_moderation, User.session)
                  relation.order(created_at: :desc)
                else
                  # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
                  relation.where.not(event_type: ['Event::CreateReport', 'Event::ReportForRequest',
                                                  'Event::ReportForProject', 'Event::ReportForPackage',
                                                  'Event::ReportForComment', 'Event::ReportForUser',
                                                  'Event::ClearedDecision', 'Event::FavoredDecision',
                                                  'Event::AppealCreated']).order(created_at: :desc)
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
    @relation.where(event_type: ['Event::CreateReport', 'Event::ReportForProject', 'Event::ReportForPackage',
                                 'Event::ReportForComment', 'Event::ReportForUser', 'Event::ReportForRequest',
                                 'Event::ClearedDecision', 'Event::FavoredDecision', 'Event::AppealCreated'], delivered: false)
  end

  def for_workflow_runs
    @relation.where(event_type: 'Event::WorkflowRunFail', delivered: false)
  end

  def for_appealed_decisions
    @relation.where(event_type: 'Event::AppealCreated', delivered: false)
  end

  def for_notifiable_type(type = 'unread')
    NOTIFIABLE_TYPE_MAP[type].call(notifications)
  end

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

  def notifications
    @notifications ||= self.class.new(with_notifiable)
  end
end
