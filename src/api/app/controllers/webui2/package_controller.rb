module Webui2::PackageController
  def webui2_show
    @comments = @package.comments.includes(:user, :children)
  end

  def webui2_submit_request_dialog
    respond_to do |format|
      format.js { render 'submit_request_dialog' }
    end
  end

  def webui2_rpmlint_result
    if @repo_list.empty?
      render partial: 'no_repositories', locals: { project: @project }
    else
      render partial: 'rpmlint_result', locals: { index: params[:index], project: @project, package: @package,
                                                  repository_list: @repo_list, repo_arch_hash: @repo_arch_hash }
    end
  end
end
