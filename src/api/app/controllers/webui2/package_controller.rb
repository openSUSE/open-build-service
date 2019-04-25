module Webui2::PackageController
  def webui2_show
    @comments = @package.comments.includes(:user)
  end

  def webui2_save
    redirect_to action: :show, project: params[:project], package: params[:package]
  end

  def webui2_rpmlint_result
    if @repo_list.empty?
      render partial: 'no_repositories', locals: { project: @project }
    else
      render partial: 'rpmlint_result', locals: { index: params[:index], project: @project, package: @package,
                                                  repository_list: @repo_list, repo_arch_hash: @repo_arch_hash }
    end
  end

  def webui2_statistics
    @repository = params[:repository]
    @package_name = params[:package]

    @statistics = LocalBuildStatistic::ForPackage.new(package: @package_name,
                                                      project: @project.name,
                                                      repository: @repository,
                                                      architecture: params[:arch]).results
  end
end
