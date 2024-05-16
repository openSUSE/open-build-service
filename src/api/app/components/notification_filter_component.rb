class NotificationFilterComponent < ApplicationComponent
  def initialize(selected_filter:, user:, projects_for_filter: ProjectsForFilterFinder.new.call, groups_for_filter: GroupsForFilterFinder.new.call)
    super

    @user = user
    @projects_for_filter = projects_for_filter
    @groups_for_filter = groups_for_filter
    @count = notifications_count
    @selected_filter = selected_filter
  end

  # TODO: Turn this into a query object `NotificationsCounter` and pass this as a default value
  #       to a keyword argument `count` in the `initialize` method
  def notifications_count
    notifications = User.session.notifications.for_web
    counted_notifications = notifications.unread.group(:notifiable_type).count
    counted_notifications['incoming_requests'] = notifications.for_incoming_requests.count
    counted_notifications['outgoing_requests'] = notifications.for_outgoing_requests.count
    counted_notifications['relationships_created'] = notifications.for_relationships_created.count
    counted_notifications['relationships_deleted'] = notifications.for_relationships_deleted.count
    counted_notifications['build_failures'] = notifications.for_failed_builds.count
    counted_notifications['reports'] = notifications.for_reports.count
    counted_notifications['workflow_runs'] = notifications.for_workflow_runs.count
    counted_notifications['appealed_decisions'] = notifications.for_appealed_decisions.count
    counted_notifications.merge!('unread' => User.session.unread_notifications)
  end
end
