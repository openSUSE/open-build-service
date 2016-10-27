class CommentProject < Comment
  validates :project, presence: true

  def check_delete_permissions
    # If you can change the project, you can delete the comment
    User.current.has_local_permission?('change_project', project) || super
  end

  def create_notification(params = {})
    super
    params[:project] = project.name
    params[:commenters] = involved_users(:project_id, project.id)

    # call the action
    Event::CommentForProject.create params
  end
end
