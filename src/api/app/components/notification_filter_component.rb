class NotificationFilterComponent < ApplicationComponent
  def initialize(notifications:, selected_filter:, user:)
    super

    @notifications = notifications
    @user = user
    @projects_for_filter = ProjectsForFilterFinder.new.call
    @groups_for_filter = GroupsForFilterFinder.new.call
    @count = notifications_count
    @selected_filter = selected_filter
  end

  # TODO: Turn this into a query object `NotificationsCounter` and pass this as a default value
  #       to a keyword argument `count` in the `initialize` method
  def notifications_count
    counted_notifications = {}
    counted_notifications['unread'] = @notifications.unread.count
    counted_notifications['read'] = @notifications.read.count
    counted_notifications['comments'] = @notifications.for_comments.count
    counted_notifications['requests'] = @notifications.for_requests.count
    counted_notifications['incoming_requests'] = @notifications.for_incoming_requests(User.session).count
    counted_notifications['outgoing_requests'] = @notifications.for_outgoing_requests(User.session).count
    counted_notifications['relationships_created'] = @notifications.for_relationships_created.count
    counted_notifications['relationships_deleted'] = @notifications.for_relationships_deleted.count
    counted_notifications['build_failures'] = @notifications.for_build_failures.count
    counted_notifications['reports'] = @notifications.for_reports.count
    counted_notifications['workflow_runs'] = @notifications.for_workflow_runs.count
    counted_notifications['appealed_decisions'] = @notifications.for_appealed_decisions.count
    @projects_for_filter.each do |project_name|
      counted_notifications["project_#{project_name}"] = @notifications.for_project_name(project_name).count
    end
    @groups_for_filter.each do |group_title|
      counted_notifications["group_#{group_title}"] = @notifications.for_group_title(group_title).count
    end
    counted_notifications
  end
end
