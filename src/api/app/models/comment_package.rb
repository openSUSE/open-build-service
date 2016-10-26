class CommentPackage < Comment
  validates :package, presence: true

  def create_notification(params = {})
    super
    params[:project] = package.project.name
    params[:package] = package.name
    params[:commenters] = involved_users(:package_id, package.id)

    # call the action
    Event::CommentForPackage.create params
  end

  def check_delete_permissions
    # If you can change the package, you can delete the comment
    User.current.has_local_permission?('change_package', package) || super
  end
end
