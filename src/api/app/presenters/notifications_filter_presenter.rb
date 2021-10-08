class NotificationsFilterPresenter
  attr_reader :selected_filter, :selected_project, :selected_group, :selected_type, :count, :projects_for_filter, :groups_for_filter

  def initialize(notifications_count, selected_type, selected_project, selected_group)
    @projects_for_filter = projects_for_filter_query
    @groups_for_filter = GroupsForFilterFinder.new.call
    @count = notifications_count
    @selected_type = selected_type
    @selected_project = selected_project
    @selected_group = selected_group
    @selected_filter = { type: selected_type, project: selected_project, group: selected_group }
  end

  private

  # TODO: This should be a simple query object
  # Returns a hash where the key is the name of the project and the value is the amount of notifications
  # associated to that project. The hash is sorted by amount and then name.
  def projects_for_filter_query
    Project.joins(:notifications)
           .where(notifications: { subscriber: User.session, delivered: false, web: true })
           .order('name desc').group(:name).count # this query returns a sorted-by-name hash like { "home:b" => 1, "home:a" => 3  }
           .sort_by(&:last).reverse.to_h # this sorts the hash by amount: { "home:a" => 3, "home:b" => 1 }
  end
end
