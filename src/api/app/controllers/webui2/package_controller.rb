module Webui2::PackageController
  def webui2_show
    @comments = @package.comments.includes(:user, :children)
  end

  def webui2_save
    redirect_to action: :show, project: params[:project], package: params[:package]
  end

  def webui2_buildresult
    if @project.repositories.any?
      show_all = params['show_all'] == 'true'
      @buildresults = @package.buildresult(@project, show_all)
      @collapsed_repositories = params.fetch(:collapsed, [])
    end

    @index = params[:index]

    respond_to do |format|
      format.js { render 'buildstatus' }
    end
  end

  def webui2_submit_request_dialog
    respond_to do |format|
      format.js { render 'submit_request_dialog' }
    end
  end

  def webui2_rpmlint_result
    if @repo_list.present?
      @repo_list.sort!
      repository_name = @repo_list[0][1]
      architecture_name = @repo_arch_hash[repository_name].last
      log_result(@project.name, @package.name, repository_name, architecture_name)
    end

    @index = params[:index]

    respond_to do |format|
      format.js { render 'rpmlint_result' }
    end
  end

  def webui2_rpmlint_log
    log_result(params[:project], params[:package], params[:repository], params[:architecture])

    @index = params[:index]

    respond_to do |format|
      format.js { render 'rpmlint_log' }
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

  private

  def log_result(project_name, package_name, repository_name, architecture_name)
    @log = Backend::Api::BuildResults::Binaries.rpmlint_log(project_name, package_name, repository_name, architecture_name)
    @log.encode!(xml: :text)
  rescue Backend::NotFoundError
  end
end
