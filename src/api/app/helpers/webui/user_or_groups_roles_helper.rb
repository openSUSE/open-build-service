module Webui::UserOrGroupsRolesHelper
  def user_or_groups_roles_delete_path(project, type, object, package)
    if package
      package_remove_role_path(project: project, "#{type}id": object, package: package)
    else
      project_remove_role_path(project: project, "#{type}id": object)
    end
  end
end
