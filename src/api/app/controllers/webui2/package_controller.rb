module Webui2::PackageController
  def webui2_submit_request_dialog
    respond_to do |format|
      format.js { render 'submit_request_dialog' }
    end
  end

  def webui2_rpmlint_result
    render partial: 'rpmlint_result', locals: { index: params[:index], project: @project, package: @package,
                                                repository_list: @repo_list, repo_arch_list: @repo_arch_list }
  end
end
