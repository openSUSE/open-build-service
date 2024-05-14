class NotificationFilterComponent < ApplicationComponent
  def initialize(relations:, selected_filter:, user:)
    super

    @relations = relations
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
    counted_notifications['unread'] = @relations.unread.count
    counted_notifications['read'] = @relations.read.count
    counted_notifications['comments'] = @relations.comments.count
    counted_notifications['requests'] = @relations.requests.count
    counted_notifications['incoming_requests'] = @relations.incoming_requests(User.session).count
    counted_notifications['outgoing_requests'] = @relations.outgoing_requests(User.session).count
    counted_notifications['relationships_created'] = @relations.relationships_created.count
    counted_notifications['relationships_deleted'] = @relations.relationships_deleted.count
    counted_notifications['build_failures'] = @relations.build_failures.count
    counted_notifications['reports'] = @relations.reports.count
    counted_notifications['workflow_runs'] = @relations.workflow_runs.count
    counted_notifications['appealed_decisions'] = @relations.appealed_decisions.count
    @projects_for_filter.each do |project_name|
      counted_notifications[project_name] = @relations.for_project(project_name).count
    end
    @groups_for_filter.each do |group_title|
      counted_notifications[group_title] = @relations.for_group(group_title).count
    end
    counted_notifications
  end
end
