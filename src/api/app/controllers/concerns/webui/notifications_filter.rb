module Webui::NotificationsFilter
  extend ActiveSupport::Concern

  # It's a sequence of multiple conditions combinations
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def filter_notifications_by_kind(notifications, filter_kind)
    return notifications if filter_kind == ['all']

    relations_kind = []
    relations_kind << notifications.for_comments if filter_kind.include?('comments')
    relations_kind << notifications.for_requests if filter_kind.include?('requests')
    relations_kind << notifications.for_incoming_requests(User.session) if filter_kind.include?('incoming_requests')
    relations_kind << notifications.for_outgoing_requests(User.session) if filter_kind.include?('outgoing_requests')
    relations_kind << notifications.for_relationships_created if filter_kind.include?('relationships_created')
    relations_kind << notifications.for_relationships_deleted if filter_kind.include?('relationships_deleted')
    relations_kind << notifications.for_build_failures if filter_kind.include?('build_failures')
    relations_kind << notifications.for_reports if filter_kind.include?('reports')
    relations_kind << notifications.for_workflow_runs if filter_kind.include?('workflow_runs')
    relations_kind << notifications.for_appealed_decisions if filter_kind.include?('appealed_decisions')
    relations_kind << notifications.for_member_on_groups if filter_kind.include?('member_on_groups')

    notifications = notifications.merge(relations_kind.inject(:or)) unless relations_kind.empty?
    notifications
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def filter_notifications_by_state(notifications, filter_state)
    return notifications.merge(notifications.unread.or(notifications.read)) if filter_state == 'all'

    if filter_state == 'read'
      notifications.read
    elsif filter_state == 'unread'
      notifications.unread
    end
  end

  def filter_notifications_by_project(notifications, filter_project)
    relations_project = filter_project.map do |project_name|
      notifications.for_project_name(project_name)
    end

    notifications = notifications.merge(relations_project.inject(:or)) unless relations_project.empty?
    notifications
  end

  def filter_notifications_by_group(notifications, filter_group)
    relations_group = filter_group.map do |group_title|
      notifications.for_group_title(group_title)
    end

    notifications = notifications.merge(relations_group.inject(:or)) unless relations_group.empty?
    notifications
  end

  def filter_notifications_by_request_state(notifications, filter_request_state)
    relations_request_state = filter_request_state.map do |request_state|
      notifications.for_request_state(request_state)
    end

    return notifications if relations_request_state.empty?

    notifications.merge(relations_request_state.inject(:or))
  end

  def filter_notifications_by_report_decision(notifications, filter_report_decision)
    return notifications if filter_report_decision.empty?

    notifications = notifications.for_reports

    relations_report_decision = []
    if filter_report_decision.include?('with_decision')
      relations_report_decision << notifications.where.not(notifiable_id: Report.without_decision.select(:id))
    end
    if filter_report_decision.include?('without_decision')
      relations_report_decision << notifications.where(notifiable_id: Report.without_decision.select(:id))
    end

    notifications.merge(relations_report_decision.inject(:or))
  end

  def filter_notifications_by_reportable_type(notifications, filter_reportable_type)
    relations_reportable_type = filter_reportable_type.map do |reportable_type|
      notifications.where(notifiable_id: Report.where(reportable_type: reportable_type).select(:id))
    end

    return notifications if relations_reportable_type.empty?

    notifications = notifications.for_reports
    notifications.merge(relations_reportable_type.inject(:or))
  end
end
