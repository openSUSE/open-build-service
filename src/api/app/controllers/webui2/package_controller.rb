module Webui2::PackageController
  def webui2_delete_dialog
    render_dialog(nil, project: @project, package: @package, cleanup_source: @cleanup_source)
  end

  def webui2_submit_request_dialog
    render_dialog(nil, project: @project, package: @package, revision: @revision, target_project: @tprj,
                  target_package: @tpkg, description: @description, cleanup_source: @cleanup_source)
  end

  def webui2_rpmlint_result
    render partial: 'rpmlint_result', locals: { index: params[:index], project: @project, package: @package,
                                                repository_list: @repo_list, repo_arch_list: @repo_arch_list }
  end
end
