module Webui2::RequestController
  def webui2_change_devel_request_dialog
    render_dialog(nil, project: @project, package: @package, current_devel_project: @current_devel_project,
                  current_devel_package: @current_devel_package)
  end
end
