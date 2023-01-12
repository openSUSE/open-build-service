class NotificationFilterComponent < ApplicationComponent
  def initialize(selected_filter:, projects_for_filter: ProjectsForFilterFinder.new.call, groups_for_filter: GroupsForFilterFinder.new.call)
    super

    @projects_for_filter = projects_for_filter
    @groups_for_filter = groups_for_filter
    @count = notifications_count
    @selected_filter = selected_filter
  end

  # TODO: Turn this into a query object `NotificationsCounter` and pass this as a default value
  #       to a keyword argument `count` in the `initialize` method
  def notifications_count
    finder = NotificationsFinder.new(User.session.notifications.for_web)
    counted_notifications = finder.unread.group(:notifiable_type).count
    counted_notifications['incoming_requests'] = finder.for_incoming_requests.count
    counted_notifications['outgoing_requests'] = finder.for_outgoing_requests.count
    counted_notifications['relationships_created'] = finder.for_relationships_created.count
    counted_notifications['relationships_deleted'] = finder.for_relationships_deleted.count
    counted_notifications['build_failures'] = finder.for_failed_builds.count
    counted_notifications.merge!('unread' => User.session.unread_notifications)
  end
end
