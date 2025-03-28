class Webui::PackageController < Webui::WebuiController
  include ParsePackageDiff
  include ScmsyncChecker
  include Webui::PackageHelper
  include Webui::ManageRelationships
  include Webui::NotificationsHandler

  # rubocop:disable Rails/LexicallyScopedActionFilter
  # The methods save_person, save_group and remove_role are defined in Webui::ManageRelationships
  before_action :set_project, only: %i[show edit update index users requests statistics revisions
                                       new branch_diff_info rdiff create remove
                                       save_person save_group remove_role view_file
                                       buildresult rpmlint_result rpmlint_log files]

  before_action :check_scmsync, only: %i[statistics users]

  before_action :require_package, only: %i[edit update show requests statistics revisions
                                           branch_diff_info rdiff remove
                                           save_person save_group remove_role view_file
                                           buildresult rpmlint_result rpmlint_log files users]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  before_action :check_ajax, only: %i[devel_project buildresult rpmlint_result]
  # make sure it's after the require_, it requires both
  before_action :require_login, except: %i[show index branch_diff_info
                                           users requests statistics revisions view_file
                                           devel_project buildresult rpmlint_result rpmlint_log files]

  prepend_before_action :lockout_spiders, only: %i[revisions rdiff requests]

  after_action :verify_authorized, only: %i[new create remove]

  def index
    render json: PackageDatatable.new(params, view_context: view_context, project: @project)
  end

  def show
    # FIXME: Remove this statement when scmsync is fully supported
    if @project.scmsync.present?
      flash[:error] = "Package sources for project #{@project.name} are received through scmsync.
                       This is not supported by the OBS frontend"
      redirect_back_or_to project_show_path(@project)
      return
    end

    if @spider_bot
      params.delete(:rev)
      params.delete(:srcmd5)
      @expand = 0
    elsif params[:expand]
      @expand = params[:expand].to_i
    else
      @expand = 1
    end

    @srcmd5 = params[:srcmd5]
    @revision_parameter = params[:rev]

    @revision = params[:rev]
    @failures = 0

    @is_current_rev = false
    if set_file_details
      if @forced_unexpand.blank? && @service_running.blank?
        @is_current_rev = (@revision == @current_rev)
      elsif @service_running
        flash.clear
        flash.now[:notice] = "Service currently running (<a href='#{package_show_path(project: @project, package: @package)}'>reload page</a>)."
      else
        @more_info = @package.service_error
        flash.now[:error] = "Files could not be expanded: #{@forced_unexpand}"
      end
    elsif @revision_parameter
      flash[:error] = "No such revision: #{@revision_parameter}"
      redirect_back_or_to({ controller: :package, action: :show, project: @project, package: @package })
      return
    end

    @comments = @package.comments.includes(:user)
    @comment = Comment.new

    @current_notification = handle_notification

    @services = @files.any? { |file| file['name'] == '_service' }

    respond_to do |format|
      format.html
      format.js
      format.json { render template: 'webui/package/show', formats: [:html] }
    end
  end

  def new
    authorize Package.new(project: @project), :create?
  end

  def edit
    authorize @package, :update?
    respond_to do |format|
      format.js
    end
  end

  def create
    @package = @project.packages.build(package_params)
    authorize @package, :create?

    @package.flags.build(flag: :sourceaccess, status: :disable) if params[:source_protection]
    @package.flags.build(flag: :publish, status: :disable) if params[:disable_publishing]

    if @package.save
      flash[:success] = "Package '#{elide(@package.name)}' was created successfully"
      redirect_to action: :show, project: params[:project], package: @package.name
    else
      flash[:error] = "Failed to create package: #{@package.errors.full_messages.join(', ')}"
      redirect_to controller: :project, action: :show, project: params[:project]
    end
  end

  def update
    authorize @package, :update?
    respond_to do |format|
      format.js do
        if @package.update(package_details_params)
          flash.now[:success] = 'Package was successfully updated.'
        else
          flash.now[:error] = 'Failed to update the package.'
        end
      end
    end
  end

  def main_object
    @package # used by mixins
  end

  def statistics
    @repository = params[:repository]
    @package_name = params[:package]

    @statistics = LocalBuildStatistic::ForPackage.new(package: @package_name,
                                                      project: @project.name,
                                                      repository: @repository,
                                                      architecture: params[:arch]).results
  end

  def users
    @users = [@project.users, @package.users].flatten.uniq
    @groups = [@project.groups, @package.groups].flatten.uniq
    @roles = Role.local_roles
    if User.session && params[:notification_id]
      @current_notification = Notification.find(params[:notification_id])
      authorize @current_notification, :update?, policy_class: NotificationCommentPolicy
    end
    @current_request_action = BsRequestAction.find(params[:request_action_id]) if User.session && params[:request_action_id]
  end

  # TODO: Remove this once request_index beta is rolled out
  def requests
    redirect_to(packages_requests_path(@project, @package)) if Flipper.enabled?(:request_index, User.session)

    @default_request_type = params[:type] if params[:type]
    @default_request_state = params[:state] if params[:state]
  end

  def revisions
    unless @package.check_source_access?
      flash[:error] = 'Could not access revisions'
      redirect_to action: :show, project: @project.name, package: @package.name
      return
    end

    revision_count = (params[:rev] || @package.rev).to_i
    per_page = User.session && params['show_all'] ? revision_count : 20
    page = (params[:page] || 1).to_i
    startbefore = revision_count - ((page - 1) * per_page) + 1
    revisions_options = { limit: per_page, deleted: 0, meta: 0 }
    revisions_options[:startbefore] = startbefore if startbefore.positive?
    revisions = Xmlhash.parse(Backend::Api::Sources::Package.revisions(@project.name, params[:package], revisions_options)).elements('revision')
    @revisions = Kaminari.paginate_array(revisions.reverse, total_count: revision_count).page(page).per(per_page)
  end

  def rdiff
    @last_rev = @package.dir_hash['rev']
    @linkinfo = @package.linkinfo
    if params[:oproject]
      @oproject = ::Project.find_by_name(params[:oproject])
      @opackage = @oproject.find_package(params[:opackage]) if @oproject && params[:opackage]
    end

    @last_req = find_last_req

    @rev = params[:rev] || @last_rev
    @linkrev = params[:linkrev]

    options = {}
    %i[orev opackage oproject linkrev olinkrev].each do |k|
      options[k] = params[k] if params[k].present?
    end
    options[:rev] = @rev if @rev
    options[:filelimit] = 0 if params[:full_diff] && User.session
    options[:tarlimit] = 0 if params[:full_diff] && User.session
    return unless get_diff(@project.name, @package.name, options)

    # we only look at [0] because this is a generic function for multi diffs - but we're sure we get one
    filenames = sorted_filenames_from_sourcediff(@rdiff)[0]

    @files = filenames['files']
    @not_full_diff = @files.any? { |file| file[1]['diff'].try(:[], 'shown') }
    @filenames = filenames['filenames']

    # FIXME: moved from the old view, needs refactoring
    @submit_url_opts = {}
    if @oproject && @opackage && !@oproject.find_attribute('OBS', 'RejectRequests') && !@opackage.find_attribute('OBS', 'RejectRequests')
      @submit_message = "Submit to #{@oproject.name}/#{@opackage.name}"
      @submit_url_opts[:target_project] = @oproject.name
      @submit_url_opts[:targetpackage] = @opackage.name
    elsif @rev != @last_rev
      @submit_message = "Revert #{@project.name}/#{@package.name} to revision #{@rev}"
      @submit_url_opts[:target_project] = @project.name
    end
  end

  def branch_diff_info
    linked_package = @package.backend_package.links_to
    target_project = target_package = description = ''
    if linked_package
      target_project = linked_package.project.name
      target_package = linked_package.name
      description = @package.commit_message_from_changes_file(target_project, target_package)
    end

    render json: {
      targetProject: target_project,
      targetPackage: target_package,
      description: description,
      cleanupSource: @project.branch? # We should remove the package if this request is a branch
    }
  end

  def remove
    authorize @package, :destroy?

    # Don't check weak dependencies if we force
    @package.check_weak_dependencies? unless params[:force]
    if @package.errors.empty?
      @package.destroy
      redirect_to(project_show_path(@project), success: 'Package was successfully removed.')
    else
      redirect_to(package_show_path(project: @project, package: @package),
                  error: "Package can't be removed: #{@package.errors.full_messages.to_sentence}")
    end
  end

  def devel_project
    tgt_pkg = Package.find_by_project_and_name(params[:project], params[:package])

    render plain: tgt_pkg.try(:develpackage).try(:project).to_s
  end

  def buildresult
    if @project.repositories.any?
      show_all = params[:show_all].to_s.casecmp?('true')
      @index = params[:index]
      @buildresults = @package.buildresult(@project, show_all: show_all)

      # TODO: this is part of the temporary changes done for 'request_show_redesign'.
      request_show_redesign_partial = 'webui/request/beta_show_tabs/build_status' if params.fetch(:inRequestShowRedesign, false)

      render partial: request_show_redesign_partial || 'buildstatus', locals: { buildresults: @buildresults,
                                                                                index: @index,
                                                                                project: @project,
                                                                                collapsed_packages: params.fetch(:collapsedPackages, []),
                                                                                collapsed_repositories: params.fetch(:collapsedRepositories, {}) }
    else
      render partial: 'no_repositories', locals: { project: @project }
    end
  end

  def rpmlint_result
    @repo_arch_hash = {}
    @buildresult = Buildresult.find_hashed(project: @project.to_param, package: @package.to_param, view: 'status')
    repos = [] # Temp var
    if @buildresult
      @buildresult.elements('result') do |result|
        if result.value('repository') != 'images' &&
           result.value('status') && result.value('status').value('code') != 'excluded'
          hash_key = valid_xml_id(elide(result.value('repository'), 30))
          @repo_arch_hash[hash_key] ||= []
          @repo_arch_hash[hash_key] << result['arch']
          repos << result.value('repository')
        end
      end
    end

    @repo_list = repos.uniq.collect do |repo_name|
      [repo_name, valid_xml_id(elide(repo_name, 30))]
    end

    if @repo_list.empty?
      render partial: 'no_repositories', locals: { project: @project }
    else
      # TODO: this is part of the temporary changes done for 'request_show_redesign'.
      request_show_redesign_partial = 'webui/request/beta_show_tabs/rpm_lint_result' if params.fetch(:inRequestShowRedesign, false)

      render partial: request_show_redesign_partial || 'rpmlint_result', locals: { index: params[:index], project: @project, package: @package,
                                                                                   repository_list: @repo_list, repo_arch_hash: @repo_arch_hash,
                                                                                   is_staged_request: params[:is_staged_request] }
    end
  end

  def rpmlint_log_params
    params.require(%i[project package repository architecture])
    params.slice(:project, :package, :repository, :architecture).permit!
  end

  def rpmlint_log
    rpmlint_log_file = RpmlintLogExtractor.new(rpmlint_log_params).call
    render plain: 'No rpmlint log' and return if rpmlint_log_file.blank?

    render_chart = params[:renderChart] == 'true'
    parsed_messages = RpmlintLogParser.new(content: rpmlint_log_file).call if render_chart
    render partial: 'rpmlint_log', locals: { rpmlint_log_file: rpmlint_log_file, render_chart: render_chart, parsed_messages: parsed_messages }
  end

  def preview_description
    markdown = helpers.render_as_markdown(params[:package][:description])
    respond_to do |format|
      format.json { render json: { markdown: markdown } }
    end
  end

  def autocomplete
    render json: AutocompleteFinder::Package.new(Package, params[:term]).call.pluck(:name).uniq
  end

  def files; end
  def view_file; end

  private

  def package_params
    params.require(:package).permit(:name, :title, :description)
  end

  def package_details_params
    # We use :package_details instead of the canonical :package param key
    # because :package is already used in the Webui::WebuiController#require_package
    # filter.
    # TODO: rename the usage of :package in #require_package to :package_name to unlock
    # the proper use of defaults.
    params
      .require(:package_details)
      .permit(:title,
              :description,
              :url,
              :report_bug_url)
  end

  def set_file_details
    @forced_unexpand ||= ''
    @is_branchable = @package.find_attribute('OBS', 'RejectBranch').nil?

    # check source access
    @files = []
    return false unless @package.check_source_access?

    set_linkinfo

    begin
      @current_rev = @package.rev
      @revision = @current_rev if !@revision && !@srcmd5 # on very first page load only

      files_xml = @package.source_file(nil, { rev: @srcmd5 || @revision, expand: @expand }.compact)
      files_hash = Xmlhash.parse(files_xml)
      @files = files_hash.elements('entry')
      @srcmd5 = files_hash['srcmd5'] unless @revision == @current_rev
    rescue Backend::Error => e
      # TODO: crudest hack ever!
      if e.summary == 'service in progress' && @expand == 1
        @expand = 0
        @service_running = true
        # silently in this case
        return set_file_details
      end
      if @expand == 1
        @forced_unexpand = e.details || e.summary
        @expand = 0
        return set_file_details
      end
      return false
    end

    true
  end

  def set_linkinfo
    return unless @package.link?

    # FIXME: We have a rails bug here.
    # the `.backend_package.links_to` is an association chain.
    # Due to this bug https://github.com/rails/rails/issues/38709 `linked_package` will not get the refreshed
    # contents and then the md5 at the bottom of this method are the same, thus no rendering the linkinfo
    linked_package = @package.backend_package.links_to
    return set_remote_linkinfo unless linked_package

    @linkinfo = { package: linked_package, error: @package.backend_package.error }
    @linkinfo[:diff] = true if linked_package.backend_package.verifymd5 != @package.backend_package.verifymd5
  end

  def set_remote_linkinfo
    linkinfo = @package.linkinfo

    return unless linkinfo && linkinfo['package'] && linkinfo['project']
    return unless Package.exists_on_backend?(linkinfo['package'], linkinfo['project'])

    @linkinfo = { remote_project: linkinfo['project'], package: linkinfo['package'] }
  end

  def find_last_req
    return if @oproject.blank? || @opackage.blank?

    last_req = find_last_declined_bs_request

    return if last_req.blank?

    { id: last_req.number, decliner: last_req.commenter,
      when: last_req.updated_at, comment: last_req.comment }
  end

  def find_last_declined_bs_request
    last_req = BsRequestAction.joins(:bs_request).where(target_project: @oproject,
                                                        target_package: @opackage,
                                                        source_project: @package.project,
                                                        source_package: @package.name)
                              .order(:bs_request_id).last

    return if last_req.blank?

    last_req.bs_request if bs_request.state == :declined
  end

  def get_diff(project, package, options = {})
    options[:view] = :xml
    options[:cacheonly] = 1 unless User.session
    options[:withissues] = 1
    begin
      @rdiff = Backend::Api::Sources::Package.source_diff(project, package, options.merge(expand: 1))
    rescue Backend::Error => e
      flash[:error] = "Problem getting expanded diff: #{e.summary}"
      begin
        @rdiff = Backend::Api::Sources::Package.source_diff(project, package, options.merge(expand: 0))
      rescue Backend::Error => e
        flash[:error] = "Error getting diff: #{e.summary}"
        redirect_back_or_to package_show_path(project: @project, package: @package)
        return false
      end
    end
    true
  end
end
