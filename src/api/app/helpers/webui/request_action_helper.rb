module Webui::RequestActionHelper
  # Returns the proper user role's tab path depending on the target (project or package)
  def roles_link(action, parameters)
    if action.target_package
      package_users_path(parameters.merge!(package: action.target_package))
    else
      project_users_path(parameters)
    end
  end
end
