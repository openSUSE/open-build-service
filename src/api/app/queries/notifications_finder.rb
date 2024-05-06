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

  # TODO: Move this to notification model
  def stale
    @relation.where('created_at < ?', notifications_lifetime.days.ago)
  end

  private

  def notifications_lifetime
    CONFIG['notifications_lifetime'] ||= 365
  end
end
