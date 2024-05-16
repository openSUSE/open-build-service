module Webui::NotificationsFilter
  extend ActiveSupport::Concern

  # It's just a case...
  # rubocop:disable Metrics/CyclomaticComplexity
  def filter_notifications_by_type(notifications, filter_type)
    case filter_type
    when 'comments'
      notifications.for_comments
    when 'requests'
      notifications.for_requests
    when 'incoming_requests'
      notifications.for_incoming_requests(User.session!)
    when 'outgoing_requests'
      notifications.for_outgoing_requests(User.session!)
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
    else # all
      notifications
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
