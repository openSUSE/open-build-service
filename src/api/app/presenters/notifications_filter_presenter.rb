class NotificationsFilterPresenter
  attr_reader :selected_filter, :selected_group, :selected_project, :selected_type,
              :count, :groups_for_filter, :projects_for_filter

  def initialize(project_filter_choices, group_filter_choices, notifications_count, selected_type)
    @groups_for_filter = group_filter_choices.choices
    @projects_for_filter = project_filter_choices.choices
    @count = notifications_count
    @selected_group = group_filter_choices.selected
    @selected_type = selected_type
    @selected_project = project_filter_choices.selected
    @selected_filter = {
      type: selected_type,
      project: selected_project,
      group: selected_group
    }
  end
end
