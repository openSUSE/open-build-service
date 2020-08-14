class NotificationsFilterPresenter
  attr_reader :selected_filter, :selected_project, :selected_type, :count, :projects_for_filter

  def initialize(projects_for_filter, notifications_count, selected_type, selected_project)
    @projects_for_filter = projects_for_filter
    @count = notifications_count
    @selected_type = selected_type
    @selected_project = selected_project
    @selected_filter = { type: selected_type, project: selected_project }
  end
end
