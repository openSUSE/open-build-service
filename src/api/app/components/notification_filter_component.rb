class NotificationFilterComponent < ApplicationComponent
  def initialize(selected_filter:, counted_notifications:, user:)
    super

    @user = user
    @projects_for_filter = ProjectsForFilterFinder.new.call
    @groups_for_filter = GroupsForFilterFinder.new.call
    @count = counted_notifications
    @selected_filter = selected_filter
  end
end
