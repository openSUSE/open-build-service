module Webui::UserOrGroupsRolesHelper
  def display_name(object)
    if object.is_a?(User) && object.realname.present?
      tag.span do
        concat("#{object.name} ")
        concat(tag.i("(#{object.login})"))
      end
    else
      tag.span(object.name)
    end
  end

  def user_or_group_path(object)
    object.is_a?(User) ? user_path(object) : group_path(object)
  end

  def user_or_groups_roles_delete_path(project, type, object, package)
    if package
      package_remove_role_path(project: project, "#{type}id": object, package: package)
    else
      project_remove_role_path(project: project, "#{type}id": object)
    end
  end
end
