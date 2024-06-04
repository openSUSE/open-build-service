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
    counted_notifications['all'] = @user.notifications.count
    counted_notifications['unread'] = @notifications.unread.count
    counted_notifications['read'] = @notifications.read.count
    counted_notifications
  end
end
