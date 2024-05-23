module Webui::NotificationsFilter
  extend ActiveSupport::Concern

  # It's a sequence of multiple conditions combinations
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def filter_notifications_by_type(notifications, filter_type)
    return notifications if filter_type == ['all']

    relations_type = []
    relations_type << notifications.for_comments if filter_type.include?('comments')
    relations_type << notifications.for_requests if filter_type.include?('requests')
    relations_type << notifications.for_incoming_requests(User.session) if filter_type.include?('incoming_requests')
    relations_type << notifications.for_outgoing_requests(User.session) if filter_type.include?('outgoing_requests')
    relations_type << notifications.for_relationships_created if filter_type.include?('relationships_created')
    relations_type << notifications.for_relationships_deleted if filter_type.include?('relationships_deleted')
    relations_type << notifications.for_build_failures if filter_type.include?('build_failures')
    relations_type << notifications.for_reports if filter_type.include?('reports')
    relations_type << notifications.for_workflow_runs if filter_type.include?('workflow_runs')
    relations_type << notifications.for_appealed_decisions if filter_type.include?('appealed_decisions')

    notifications = notifications.merge(relations_type.inject(:or)) unless relations_type.empty?
    notifications
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
end
