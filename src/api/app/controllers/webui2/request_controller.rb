module Webui2::RequestController
  def webui2_change_devel_request_dialog
    render_dialog(nil, project: @project, package: @package, current_devel_project: @current_devel_project,
                  current_devel_package: @current_devel_package)
  end

  def webui2_add_role_request_dialog
    render_dialog(nil, project: @project, package: @package)
  end

  def webui2_delete_request_dialog
    render_dialog(nil, project: @project, package: @package)
  end
end

