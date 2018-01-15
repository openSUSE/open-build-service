require 'open-uri'
require 'project'

class Webui::PackageController < Webui::WebuiController
  require_dependency 'opensuse/validator'
  include ParsePackageDiff
  include Webui::PackageHelper
  include Webui::LoadBuildresults
  include Webui::ManageRelationships
  include BuildLogSupport

  before_action :set_project, only: [:show, :users, :linking_packages, :dependency, :binary, :binaries,
                                     :requests, :statistics, :commit, :revisions, :submit_request_dialog,
                                     :add_person, :add_group, :rdiff, :save_new,
                                     :save, :delete_dialog,
                                     :remove, :add_file, :save_file, :remove_file, :save_person,
                                     :save_group, :remove_role, :view_file,
                                     :abort_build, :trigger_rebuild, :trigger_services,
                                     :wipe_binaries, :buildresult, :rpmlint_result, :rpmlint_log, :meta,
                                     :save_meta, :attributes, :edit, :import_spec, :files]

  before_action :require_package, only: [:show, :linking_packages, :dependency, :binary, :binaries,
                                         :requests, :statistics, :commit, :revisions, :submit_request_dialog,
                                         :add_person, :add_group, :rdiff,
                                         :save, :delete_dialog,
                                         :remove, :add_file, :save_file, :remove_file, :save_person,
                                         :save_group, :remove_role, :view_file,
                                         :abort_build, :trigger_rebuild, :trigger_services,
                                         :wipe_binaries, :buildresult, :rpmlint_result, :rpmlint_log, :meta,
                                         :attributes, :edit, :import_spec, :files, :users]

  # make sure it's after the require_, it requires both
  before_action :require_login, except: [:show, :linking_packages, :linking_packages, :dependency,
                                         :binary, :binaries, :users, :requests, :statistics, :commit,
                                         :revisions, :rdiff, :view_file, :live_build_log,
                                         :update_build_log, :devel_project, :buildresult, :rpmlint_result,
                                         :rpmlint_log, :meta, :attributes, :files]

  before_action :check_build_log_access, only: [:live_build_log, :update_build_log]

  prepend_before_action :lockout_spiders, only: [:revisions, :dependency, :rdiff, :binary, :binaries, :requests]

  def show
    if lockout_spiders
      params.delete(:rev)
      params.delete(:srcmd5)
    end

    @srcmd5 = params[:srcmd5]
    @revision_parameter = params[:rev]

    @bugowners_mail = (@package.bugowner_emails + @project.api_obj.bugowner_emails).uniq
    @revision = params[:rev]
    @failures = 0

    if @spider_bot
      @expand = 0
    elsif params[:expand]
      @expand = params[:expand].to_i
    else
      @expand = 1
    end

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
      redirect_back(fallback_location: { controller: :package, action: :show, project: @project, package: @package })
      return
    end

    @comments = @package.comments
    @comment = Comment.new
    @requests = []
    @services = Service.find(project: @project.name, package: @package.name)
  end

  def main_object
    @package # used by mixins
  end

  def linking_packages
    render_dialog
  end

  def dependency
    unless Project.find_by_name(params[:dproject].to_s)
      flash[:error] = "Project '#{params[:dproject]}' is invalid."
      redirect_back(fallback_location: root_path)
      return
    end

    unless Architecture.archcache.include?(params[:arch])
      flash[:error] = "Architecture '#{params[:arch]}' is invalid."
      redirect_back(fallback_location: project_show_path(project: params[:dproject]))
      return
    end
    project_repositories = Project.find_by_name(params[:dproject]).repositories.pluck(:name)
    [:repository, :drepository].each do |repo_key|
      next if project_repositories.include?(params[repo_key])
      flash[:error] = "Repository '#{params[repo_key]}' is invalid."
      redirect_back(fallback_location: project_show_path(project: params[:dproject]))
      # rubocop:disable Lint/NonLocalExitFromIterator
      return
      # rubocop:enable Lint/NonLocalExitFromIterator
    end

    @arch = params[:arch]
    @repository = params[:repository]
    @drepository = params[:drepository]
    @dproject = params[:dproject]
    # Ensure it really is just a file name, no '/..', etc.
    @filename = File.basename(params[:filename])
    @fileinfo = Fileinfo.find(project: params[:dproject], package: '_repository', repository: params[:drepository], arch: @arch,
      filename: params[:dname], view: 'fileinfo_ext')
    @durl = nil
    return if @fileinfo # avoid displaying an error for non-existing packages
    redirect_back(fallback_location: { action: :binary, project: params[:project], package: params[:package],
                                       repository: @repository, arch: @arch, filename: @filename })
  end

  def statistics
    required_parameters :arch, :repository
    @arch = params[:arch]
    @repository = params[:repository]
    @statistics = nil
    begin
      @statistics = Statistic.find_hashed(project: @project, package: @package, repository: @repository, arch: @arch)
    rescue ActiveXML::Transport::ForbiddenError
    end

    return if @statistics.present?
    flash[:error] = "No statistics of a successful build could be found in #{@repository}/#{@arch}"
    redirect_to controller: 'package', action: :binaries, project: @project,
                package: @package, repository: @repository, nextstatus: 404
  end

  def binary
    required_parameters :arch, :repository, :filename
    @arch = params[:arch]
    @repository = params[:repository]
    # Ensure it really is just a file name, no '/..', etc.
    @filename = File.basename(params[:filename])

    begin
      @fileinfo = Fileinfo.find(project: @project, package: @package, repository: @repository, arch: @arch,
        filename: @filename, view: 'fileinfo_ext')
    rescue ActiveXML::Transport::ForbiddenError => e
      flash[:error] = "File #{@filename} can not be downloaded from #{@project}: #{e.summary}"
    end
    unless @fileinfo
      flash[:error] = "File \"#{@filename}\" could not be found in #{@repository}/#{@arch}"
      redirect_to controller: :package, action: :binaries, project: @project,
                  package: @package, repository: @repository, nextstatus: 404
      return
    end

    repo = Repository.find_by_project_and_name(@project.to_s, @repository.to_s)
    @durl = repo.download_url_for_file(@package, @arch, @filename)
    @durl = nil if @durl && !file_available?(@durl) # ignore files not available
    unless User.current.is_nobody? || @durl
      # only use API for logged in users if the mirror is not available
      @durl = rpm_url(@project, @package, @repository, @arch, @filename)
    end
    logger.debug "accepting #{request.accepts.join(',')} format:#{request.format}"
    # little trick to give users eager to download binaries a single click
    redirect_to @durl && return if request.format != Mime[:html] && @durl
  end

  def binaries
    required_parameters :repository
    @repository = params[:repository]
    begin
      @buildresult = Buildresult.find_hashed(project: @project, package: @package,
        repository: @repository, view: %w[binarylist status])
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.message
      redirect_back(fallback_location: { controller: :package, action: :show, project: @project, package: @package })
      return
    end
    return if @buildresult

    flash[:error] = "Package \"#{@package}\" has no build result for repository #{@repository}"
    redirect_to controller: :package, action: :show, project: @project, package: @package, nextstatus: 404
  end

  def users
    @users = [@project.users, @package.users].flatten.uniq
    @groups = [@project.groups, @package.groups].flatten.uniq
    @roles = Role.local_roles
  end

  def requests
    @default_request_type = params[:type] if params[:type]
    @available_types = %w[all submit delete add_role change_devel maintenance_incident maintenance_release]
    @default_request_state = params[:state] if params[:state]
    @available_states = ['new or review', 'new', 'review', 'accepted', 'declined', 'revoked', 'superseded']
  end

  def commit
    required_parameters :revision
    render partial: 'commit_item', locals: { rev: params[:revision] }
  end

  def revisions
    unless @package.check_source_access?
      flash[:error] = 'Could not access revisions'
      redirect_to action: :show, project: @project.name, package: @package.name
      return
    end
    @lastrev = params[:rev].try(:to_i) || @package.rev.to_i
    if params[:showall] || @lastrev < 21
      @revisions = (1..@lastrev).to_a.reverse
    else
      @revisions = []
      @lastrev.downto(@lastrev - 19) { |n| @revisions << n }
    end
  end

  def submit_request_dialog
    if params[:revision]
      @revision = params[:revision]
    else
      @revision = @package.rev
    end
    @cleanup_source = @project.name.include?(':branches:') # Rather ugly decision finding...
    @tprj = ''
    lt = @package.backend_package.links_to
    if lt
      @tprj = lt.project.name # fill in from link
      @tpkg = lt.name
    end
    @tprj = params[:targetproject] if params[:targetproject] # allow to override by parameter
    @tpkg = params[:targetpackage] if params[:targetpackage] # allow to override by parameter

    @description = @package.commit_message(@tprj, @tpkg)

    render_dialog
  end

  # FIXME: This should be in Webui::RequestController
  def submit_request
    required_parameters :project, :package

    target_project_name = params[:targetproject].try(:strip)
    package_name = params[:package].strip
    project_name = params[:project].strip

    if params[:targetpackage].blank?
      target_package_name = package_name
    else
      target_package_name = params[:targetpackage].try(:strip)
    end

    if target_project_name.blank?
      flash[:error] = 'Please provide a target for the submit request'
      redirect_to action: :show, project: project_name, package: package_name
      return
    end

    req = nil
    begin
      BsRequest.transaction do
        req = BsRequest.new(state: 'new')
        req.description = params[:description]

        opts = { source_project: project_name,
                 source_package: package_name,
                 target_project: target_project_name,
                 target_package: target_package_name }
        if params[:sourceupdate]
          opts[:sourceupdate] = params[:sourceupdate]
        elsif params[:project].include?(':branches:')
          opts[:sourceupdate] = 'update' # Avoid auto-removal of branch
        end
        opts[:source_rev] = params[:rev] if params[:rev]
        action = BsRequestActionSubmit.new(opts)
        req.bs_request_actions << action
        action.bs_request = req

        req.set_add_revision
        req.save!
      end
    rescue BsRequestAction::DiffError => e
      flash[:error] = "Unable to diff sources: #{e.message}"
    rescue BsRequestAction::MissingAction => e
      flash[:error] = 'Unable to submit, sources are unchanged'
    rescue Project::UnknownObjectError,
           BsRequestAction::UnknownProject,
           BsRequestAction::UnknownTargetPackage => e
      redirect_back(fallback_location: root_path, error: "Unable to submit (missing target): #{e.message}")
      return
    rescue APIException, ActiveRecord::RecordInvalid => e
      flash[:error] = "Unable to submit: #{e.message}"
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = "Unable to submit: #{e.message}"
    end

    if flash[:error]
      if package_name.blank?
        redirect_to(project_show_path(project: project_name))
      else
        redirect_to(package_show_path(project: project_name, package: package_name))
      end
      return
    end

    # Supersede logic has to be below addition as we need the new request id
    supersede_errors = []
    if params[:supersede_request_numbers]
      params[:supersede_request_numbers].each do |request_number|
        begin
          r = BsRequest.find_by_number! request_number
          opts = {
            newstate:      'superseded',
            reason:        "Superseded by request #{req.number}",
            superseded_by: req.number
          }
          r.change_state(opts)
        rescue APIException => e
          supersede_errors << e.message.to_s
        end
      end
    end

    if supersede_errors.any?
      supersede_notice = 'Superseding failed: '
      supersede_notice += supersede_errors.join('. ')
    end
    flash[:notice] = "Created <a href='#{request_show_path(req.number)}'>submit request #{req.number}</a>\
                      to <a href='#{project_show_path(target_project_name)}'>#{target_project_name}</a>
                      #{supersede_notice}"
    redirect_to(action: 'show', project: project_name, package: package_name)
  end

  def set_linkinfo
    @linkinfo = nil
    lt = @package.backend_package.links_to
    return unless lt
    @linkinfo = { package: lt, error: @package.backend_package.error }
    @linkinfo[:diff] = true if lt.backend_package.verifymd5 != @package.backend_package.verifymd5
  end

  def set_file_details
    @forced_unexpand ||= ''

    # check source access
    return false unless @package.check_source_access?

    set_linkinfo

    begin
      @current_rev = @package.rev
      @revision = @current_rev if !@revision && !@srcmd5 # on very first page load only

      @files = package_files(@srcmd5 || @revision, @expand)
    rescue ActiveXML::Transport::Error => e
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
      @files = []
      return false
    end

    @spec_count = 0
    @files.each do |file|
      @spec_count += 1 if file[:ext] == 'spec'
    end

    # check source service state
    @package.serviceinfo.value(:error) if @package.serviceinfo

    true
  end
  private :set_file_details

  def add_person; end

  def add_group; end

  def find_last_req
    if @oproject && @opackage
      last_req = BsRequestAction.where(target_project: @oproject,
                                       target_package: @opackage,
                                       source_project: @package.project,
                                       source_package: @package.name).order(:bs_request_id).last
      return unless last_req
      last_req = last_req.bs_request
      if last_req.state != :declined
        return # ignore all !declined
      end
      return {
        id:       last_req.number,
        decliner: last_req.commenter,
        when:     last_req.updated_at,
        comment:  last_req.comment
      }
    end
    return
  end

  class DiffError < APIException
  end

  def get_diff(project, package, options = {})
    begin
      @rdiff = Backend::Api::Sources::Package.source_diff(project, package, options.merge(expand: 1))
    rescue ActiveXML::Transport::Error => e
      flash[:error] = 'Problem getting expanded diff: ' + e.summary
      begin
        @rdiff = Backend::Api::Sources::Package.source_diff(project, package, options.merge(expand: 0))
      rescue ActiveXML::Transport::Error => e
        flash[:error] = 'Error getting diff: ' + e.summary
        redirect_back(fallback_location: package_show_path(project: @project, package: @package))
        return false
      end
    end
    true
  end

  def rdiff
    @last_rev = @package.dir_hash['rev']
    @linkinfo = @package.linkinfo
    if params[:oproject]
      @oproject = Project.find_by_name(params[:oproject])
      @opackage = @oproject.find_package(params[:opackage]) if @oproject && params[:opackage]
    end

    @last_req = find_last_req

    @rev = params[:rev] || @last_rev
    @linkrev = params[:linkrev]

    options = {}
    [:orev, :opackage, :oproject, :linkrev, :olinkrev].each do |k|
      options[k] = params[k] if params[k].present?
    end
    options[:rev] = @rev if @rev
    options[:filelimit] = 0 if params[:full_diff]
    options[:tarlimit] = 0 if params[:full_diff]
    return unless get_diff(@project.name, @package.name, options)

    # we only look at [0] because this is a generic function for multi diffs - but we're sure we get one
    filenames = sorted_filenames_from_sourcediff(@rdiff)[0]

    @files = filenames['files']
    @not_full_diff = @files.any? { |file| file[1]['diff']['shown'] }
    @filenames = filenames['filenames']
  end

  def save_new
    @package_name = params[:name]
    @package_title = params[:title]
    @package_description = params[:description]

    return unless check_package_name_for_new

    @package = @project.packages.build(name: @package_name)
    @package.title = params[:title]
    @package.description = params[:description]
    if params[:source_protection]
      @package.flags.build flag: :sourceaccess, status: :disable
    end
    if params[:disable_publishing]
      @package.flags.build flag: :publish, status: :disable
    end
    if @package.save
      flash[:notice] = "Package '#{@package.name}' was created successfully"
      redirect_to action: :show, project: params[:project], package: @package_name
    else
      flash[:notice] = "Failed to create package '#{@package}'"
      redirect_to controller: :project, action: :show, project: params[:project]
    end
  end

  def check_package_name_for_new
    unless Package.valid_name? @package_name
      flash[:error] = "Invalid package name: '#{@package_name}'"
      redirect_to controller: :project, action: :new_package, project: @project
      return false
    end
    if Package.exists_by_project_and_name @project.name, @package_name
      flash[:error] = "Package '#{@package_name}' already exists in project '#{@project}'"
      redirect_to controller: :project, action: :new_package, project: @project
      return false
    end
    @project = @project.api_obj
    unless User.current.can_create_package_in? @project
      flash[:error] = "You can't create packages in #{@project.name}"
      redirect_to controller: :project, action: :new_package, project: @project
      return false
    end
    true
  end

  def branch
    params.fetch(:linked_project) { raise ArgumentError, 'Linked Project parameter missing' }
    params.fetch(:linked_package) { raise ArgumentError, 'Linked Package parameter missing' }

    # Full permission check happens in BranchPackage.new(branch_params).branch command
    # Are we linking a package from a remote instance?
    # Then just try, the remote instance will handle checking for existence authorization etc.
    if Project.find_remote_project(params[:linked_project])
      source_project_name = params[:linked_project]
      source_package_name = params[:linked_package]
    else
      options = { use_source: false, follow_project_links: true, follow_multibuild: true }
      source_package = Package.get_by_project_and_name(params[:linked_project], params[:linked_package], options)

      source_project_name = source_package.project.name
      source_package_name = source_package.name
      authorize source_package, :branch?
    end

    branch_params = {
      project: source_project_name,
      package: source_package_name
    }

    # Set the branch to the current revision if revision is present
    if params[:current_revision].present?
      dirhash = Directory.hashed(project: source_project_name, package: source_package_name, expand: 1)
      branch_params[:rev] = dirhash['xsrcmd5'] || dirhash['rev']

      unless branch_params[:rev]
        flash[:error] = dirhash['error'] || 'Package has no source revision yet'
        redirect_back(fallback_location: root_path)
        return
      end
    end

    branch_params[:target_project] = params[:target_project] if params[:target_project].present?
    branch_params[:target_package] = params[:target_package] if params[:target_package].present?
    branch_params[:add_repositories_rebuild] = params[:add_repositories_rebuild] if params[:add_repositories_rebuild].present?

    branched_package = BranchPackage.new(branch_params).branch
    created_project_name = branched_package[:data][:targetproject]
    created_package_name = branched_package[:data][:targetpackage]

    Event::BranchCommand.create(project: source_project_name, package: source_package_name,
                                targetproject: created_project_name, targetpackage: created_package_name,
                                user: User.current.login)

    branched_package_object = Package.find_by_project_and_name(created_project_name, created_package_name)

    if request.env['HTTP_REFERER'] == image_templates_url && branched_package_object.kiwi_image?
      redirect_to(import_kiwi_image_path(branched_package_object.id))
    else
      flash[:notice] = 'Successfully branched package'
      redirect_to(package_show_path(project: created_project_name, package: created_package_name))
    end
  rescue BranchPackage::DoubleBranchPackageError => exception
    flash[:notice] = 'You have already branched this package'
    redirect_to(package_show_path(project: exception.project, package: exception.package))
  rescue Package::UnknownObjectError, Project::UnknownObjectError
    flash[:error] = 'Failed to branch: Package does not exist.'
    redirect_back(fallback_location: root_path)
  rescue ArgumentError => exception
    flash[:error] = "Failed to branch: #{exception.message}"
    redirect_back(fallback_location: root_path)
  rescue CreateProjectNoPermission
    flash[:error] = 'Sorry, you are not authorized to create this Project.'
    redirect_back(fallback_location: root_path)
  rescue APIException, ActiveRecord::RecordInvalid => exception
    flash[:error] = "Failed to branch: #{exception.message}"
    redirect_back(fallback_location: root_path)
  end

  def save
    unless User.current.can_modify_package? @package
      redirect_to action: :show, project: params[:project], package: params[:package], error: 'No permission to save'
      return
    end
    @package.title = params[:title]
    @package.description = params[:description]
    if @package.save
      flash[:notice] = "Package data for '#{@package.name}' was saved successfully"
      redirect_to action: :show, project: params[:project], package: params[:package]
    else
      flash[:error] = "Failed to save package '#{@package.name}': #{@package.errors.full_messages.to_sentence}"
      redirect_to action: :edit, project: params[:project], package: params[:package]
    end
  end

  def delete_dialog
    render_dialog
  end

  def remove
    authorize @package, :destroy?

    # Don't check weak dependencies if we force
    @package.check_weak_dependencies? unless params[:force]
    if @package.errors.empty?
      @package.destroy
      redirect_to(project_show_path(@project), notice: 'Package was successfully removed.')
    else
      redirect_to(package_show_path(project: @project, package: @package),
                  notice: "Package can't be removed: #{@package.errors.full_messages.to_sentence}")
    end
  end

  def trigger_services
    begin
      Backend::Api::Sources::Package.trigger_services(@project.name, @package.name, User.current.to_s)
      flash[:notice] = 'Services successfully triggered'
    rescue Timeout::Error => e
      flash[:error] = "Services couldn't be triggered: " + e.message
    rescue ActiveXML::Transport::NotFoundError, ActiveXML::Transport::Error => e
      flash[:error] = "Services couldn't be triggered: " + Xmlhash::XMLHash.new(error: e.summary)[:error]
    end
    redirect_to package_show_path(@project, @package)
  end

  def add_file
    set_file_details
  end

  def save_file
    authorize @package, :update?

    file = params[:file]
    file_url = params[:file_url]
    filename = params[:filename]

    errors = []

    begin
      if file.present?
        # We are getting an uploaded file
        filename = file.original_filename if filename.blank?
        @package.save_file(file: file, filename: filename, comment: params[:comment])
      elsif file_url.present?
        # we have a remote file URI, so we have to download and save it
        services = @package.services

        # detects automatically git://, src.rpm formats
        services.addDownloadURL(file_url, filename)

        unless services.save
          errors << "Failed to add file from URL '#{file_url}'"
        end
      elsif filename.present? # No file is provided so we just create an empty new file (touch)
        @package.save_file(filename: filename)
      else
        errors << 'No file or URI given'
      end
    rescue APIException => e
      errors << e.message
    rescue ActiveXML::Transport::Error => e
      errors << Xmlhash::XMLHash.new(error: e.summary)[:error]
    rescue StandardError => e
      errors << e.message
    end

    if errors.empty?
      message = "The file '#{filename}' has been successfully saved."
      # We have to check if it's an AJAX request or not
      if request.xhr?
        flash.now[:success] = message
        render layout: false, partial: 'layouts/webui/flash', object: flash
      else
        redirect_to({ action: :show, project: @project, package: @package }, success: message)
      end
      return
    else
      message = "Error while creating '#{filename}' file: #{errors.compact.join("\n")}."
      # We have to check if it's an AJAX request or not
      if request.xhr?
        flash.now[:error] = message
        render layout: false, status: 400, partial: 'layouts/webui/flash', object: flash
      else
        redirect_back(fallback_location: root_path, error: message)
      end
    end
  end

  def remove_file
    required_parameters :filename
    filename = params[:filename]
    begin
      @package.delete_file filename
      flash[:notice] = "File '#{filename}' removed successfully"
    rescue ActiveXML::Transport::NotFoundError
      flash[:notice] = "Failed to remove file '#{filename}'"
    end
    redirect_to action: :show, project: @project, package: @package
  end

  def view_file
    @filename = params[:filename] || params[:file] || ''
    if Package.is_binary_file?(@filename) # We don't want to display binary files
      flash[:error] = "Unable to display binary file #{@filename}"
      redirect_back(fallback_location: { action: :show, project: @project, package: @package })
      return
    end
    @rev = params[:rev]
    @expand = params[:expand]
    @addeditlink = false
    if User.current.can_modify_package?(@package) && @rev.blank?
      begin
        files = package_files(@rev, @expand)
      rescue ActiveXML::Transport::Error
        files = []
      end
      files.each do |file|
        if file[:name] == @filename
          @addeditlink = file[:editable]
          break
        end
      end
    end
    begin
      @file = @package.source_file(@filename, fetch_from_params(:rev, :expand))
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "File not found: #{@filename}"
      redirect_to action: :show, package: @package, project: @project
      return
    rescue ActiveXML::Transport::Error => e
      flash[:error] = "Error: #{e}"
      redirect_back(fallback_location: { action: :show, project: @project, package: @package })
      return
    end
    render(template: 'webui/package/simple_file_view') && return if @spider_bot
  end

  def fetch_from_params(*arr)
    opts = {}
    arr.each do |k|
      opts[k] = params[k] if params[k].present?
    end
    opts
  end

  def set_job_status
    @percent = nil

    begin
      jobstatus = get_job_status(@project, @package, @repo, @arch)
      if jobstatus.present?
        js = Xmlhash.parse(jobstatus)
        @workerid = js.get('workerid')
        @buildtime = Time.now.to_i - js.get('starttime').to_i
        ld = js.get('lastduration')
        @percent = (@buildtime * 100) / ld.to_i if ld.present?
      end
    rescue
      @workerid = nil
      @buildtime = nil
    end
  end

  def live_build_log
    @repo = @project.repositories.find_by(name: params[:repository]).try(:name)
    unless @repo
      flash[:error] = "Couldn't find repository '#{params[:repository]}'. Are you sure it still exists?"
      redirect_to(package_show_path(@project, @package))
      return
    end

    @arch = Architecture.archcache[params[:arch]].try(:name)
    unless @arch
      flash[:error] = "Couldn't find architecture '#{params[:arch]}'. Are you sure it still exists?"
      redirect_to(package_show_path(@project, @package))
      return
    end

    @offset = 0
    @status = get_status(@project, @package, @repo, @arch)
    @what_depends_on = Package.what_depends_on(@project, @package, @repo, @arch)

    set_job_status
  end

  def set_initial_offset
    # Do not start at the beginning long time ago

    size = get_size_of_log(@project, @package, @repo, @arch)
    logger.debug("log size is #{size}")
    @offset = [0, size - 32 * 1024].max
  rescue => e
    logger.error "Got #{e.class}: #{e.message}; returning empty log."
  end

  def update_build_log
    check_ajax

    # Make sure objects don't contain invalid chars (eg. '../')
    @repo = @project.repositories.find_by(name: params[:repository]).try(:name)
    unless @repo
      @errors = "Couldn't find repository '#{params[:repository]}'. We don't have build log for this repository"
      return
    end

    @arch = Architecture.archcache[params[:arch]].try(:name)
    unless @arch
      @errors = "Couldn't find architecture '#{params[:arch]}'. We don't have build log for this architecture"
      return
    end

    @initial = params[:initial]
    @offset = params[:offset].to_i
    @status = params[:status]
    @maxsize = 1024 * 64

    @finished = Buildresult.final_status?(@status)
    @offset = 0 if @finished

    set_initial_offset if @offset.zero?

    begin
      chunk = get_log_chunk(@project, @package, @repo, @arch, @offset, @offset + @maxsize)

      if chunk.length.zero? && @initial == '0' && !@finished
        # reset offset and fetch the last chunk again, because build compare overwrites last log lines
        set_initial_offset
        @log_chunk = get_log_chunk(@project, @package, @repo, @arch, @offset, @offset + @maxsize)
        @finished = true
      else
        @log_chunk = chunk
        @offset += ActiveXML.backend.last_body_length
      end
    rescue Timeout::Error, IOError
      @log_chunk = ''
    rescue ActiveXML::Transport::Error => e
      if e.summary =~ %r{Logfile is not that big}
        @log_chunk = ''
      elsif e.summary =~ /start out of range/
        # probably build compare has cut log and offset is wrong, reset offset
        @log_chunk = ''
        @offset = 0
      else
        @log_chunk = "No live log available: #{e.summary}\n"
        @finished = true
      end
    end

    logger.debug 'finished ' + @finished.to_s
  end

  def abort_build
    authorize @package, :update?

    if @package.abort_build(params)
      flash[:notice] = "Triggered abort build for #{@project.name}/#{@package.name} successfully."
      redirect_to package_show_path(project: @project, package: @package)
    else
      flash[:error] = "Error while triggering abort build for #{@project.name}/#{@package.name}: #{@package.errors.full_messages.to_sentence}."
      redirect_to package_live_build_log_path(project: @project, package: @package, repository: params[:repository], arch: params[:arch])
    end
  end

  def trigger_rebuild
    authorize @package, :update?

    if @package.rebuild(params)
      flash[:notice] = "Triggered rebuild for #{@project.name}/#{@package.name} successfully."
      redirect_to package_show_path(project: @project, package: @package)
    else
      flash[:error] = "Error while triggering rebuild for #{@project.name}/#{@package.name}: #{@package.errors.full_messages.to_sentence}."
      redirect_to package_binaries_path(project: @project, package: @package, repository: params[:repository])
    end
  end

  def wipe_binaries
    authorize @package, :update?

    if @package.wipe_binaries(params)
      flash[:notice] = "Triggered wipe binaries for #{@project.name}/#{@package.name} successfully."
      redirect_to package_binaries_path(project: @project, package: @package, repository: params[:repository])
    else
      flash[:error] = "Error while triggering wipe binaries for #{@project.name}/#{@package.name}: #{@package.errors.full_messages.to_sentence}."
      redirect_to package_binaries_path(project: @project, package: @package, repository: params[:repository])
    end
  end

  def devel_project
    check_ajax
    required_parameters :package, :project
    tgt_pkg = Package.find_by_project_and_name(params[:project], params[:package])

    render plain: tgt_pkg.try(:develpackage).try(:project).to_s
  end

  def import_spec
    all_files = package_files
    all_files.each do |file|
      @specfile_name = file[:name] if file[:name].end_with?('.spec')
    end
    if @specfile_name.blank?
      render json: {}
      return
    end
    specfile_content = @package.source_file(@specfile_name)

    description = []
    lines = specfile_content.split(/\n/)
    line = lines.shift until line =~ /^%description\s*$/
    description << lines.shift until description.last =~ /^%/
    # maybe the above end-detection of the description-section could be improved like this:
    # description << lines.shift until description.last =~ /^%\{?(debug_package|prep|pre|preun|....)/
    description.pop

    render json: { description: description }
  end

  def buildresult
    check_ajax
    if @project.repositories.any?
      @buildresults = @package.buildresults(@project)
      render partial: 'buildstatus'
    else
      render partial: 'no_repositories'
    end
  end

  def rpmlint_result
    check_ajax
    @repo_list = []
    @repo_arch_hash = {}
    @buildresult = Buildresult.find_hashed(project: @project.to_param, package: @package.to_param, view: 'status')
    repos = [] # Temp var
    if @buildresult
      @buildresult.elements('result') do |result|
        if result.value('repository') != 'images' &&
           (result.value('status') && result.value('status').value('code') != 'excluded')
          hash_key = valid_xml_id(elide(result.value('repository'), 30))
          @repo_arch_hash[hash_key] ||= []
          @repo_arch_hash[hash_key] << result['arch']
          repos << result.value('repository')
        end
      end
    end
    repos.uniq.each do |repo_name|
      @repo_list << [repo_name, valid_xml_id(elide(repo_name, 30))]
    end
    if @repo_list.empty?
      render partial: 'no_repositories'
    else
      render partial: 'rpmlint_result', locals: { index: params[:index] }
    end
  end

  def rpmlint_log
    required_parameters :project, :package, :repository, :architecture
    begin
      @log = Backend::Api::BuildResults::Binaries.rpmlint_log(params[:project], params[:package], params[:repository], params[:architecture])
      @log.encode!(xml: :text)
      render partial: 'rpmlint_log'
    rescue ActiveXML::Transport::NotFoundError
      render plain: 'No rpmlint log'
    end
  end

  def meta
    @meta = @package.render_xml
  end

  def save_meta
    errors = []

    begin
      Suse::Validator.validate('package', params[:meta])
      meta_xml = Xmlhash.parse(params[:meta])

      # That's a valid XML file
      if Package.exists_by_project_and_name(@project.name, params[:package], follow_project_links: false)
        @package = Package.get_by_project_and_name(@project.name, params[:package], use_source: false, follow_project_links: false)
        authorize @package, :update?

        if @package && !@package.disabled_for?('sourceaccess', nil, nil) && FlagHelper.xml_disabled_for?(meta_xml, 'sourceaccess')
          errors << 'admin rights are required to raise the protection level of a package'
        end

        if meta_xml['project'] && meta_xml['project'] != @project.name
          errors << 'project name in xml data does not match resource path component'
        end

        if meta_xml['name'] && meta_xml['name'] != @package.name
          errors << 'package name in xml data does not match resource path component'
        end
      else
        errors << "Package doesn't exists in that project."
      end
    rescue Suse::ValidationError => e
      errors << e.message
    end

    if errors.empty?
      @package.update_from_xml(meta_xml)
      flash.now[:success] = 'The Meta file has been successfully saved.'
      render layout: false, partial: 'layouts/webui/flash', object: flash
    else
      flash.now[:error] = "Error while saving the Meta file: #{errors.compact.join("\n")}."
      render layout: false, status: 400, partial: 'layouts/webui/flash', object: flash
    end
  end

  def edit; end

  private

  def package_files(rev = nil, expand = nil)
    query = {}
    query[:expand]  = expand  if expand
    query[:rev]     = rev     if rev

    # FIXME: This should be something like ActiveXML::Node.find!
    # so we can require ActiveXML::Node to tell us when things do not exist
    dir = ActiveXML::Node.new(@package.source_file(nil, query))
    return [] unless dir

    @serviceinfo = dir.find_first(:serviceinfo)
    files = []
    dir.each(:entry) do |entry|
      file = Hash[*[:name, :size, :mtime, :md5].map { |x| [x, entry.value(x.to_s)] }.flatten]
      file[:viewable] = !Package.is_binary_file?(file[:name]) && file[:size].to_i < 2**20 # max. 1 MB
      file[:editable] = file[:viewable] && !file[:name].match?(/^_service[_:]/)
      file[:srcmd5] = dir.value(:srcmd5)
      files << file
    end
    files
  end

  def file_available?(url, max_redirects = 5)
    logger.debug "Checking url: #{url}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 15
    http.read_timeout = 15
    response = http.head uri.path
    if response.code.to_i == 302 && response['location'] && max_redirects > 0
      return file_available? response['location'], (max_redirects - 1)
    end
    return response.code.to_i == 200
  rescue Object => e
    logger.error "Error in checking for file #{url}: #{e.message}"
    return false
  end

  def users_path
    url_for(action: :users, project: @project, package: @package)
  end

  def add_path(action)
    url_for(action: action, project: @project, role: params[:role], userid: params[:userid], package: @package)
  end

  # Basically backend stores date in /source (package sources) and /build (package
  # build related). Logically build logs are stored in /build. Though build logs also
  # contain information related to source packages.
  # Thus before giving access to the build log, we need to ensure user has source access
  # rights.
  #
  # This before_filter checks source permissions for packages that belong to remote projects,
  # to local projects and local projects that link to other project's packages.
  #
  # If the check succeeds it sets @project and @package variables.
  def check_build_log_access
    if Project.exists_by_name(params[:project])
      @project = Project.get_by_name(params[:project])
    else
      redirect_to root_path, error: "Couldn't find project '#{params[:project]}'. Are you sure it still exists?"
      return false
    end

    begin
      @package = Package.get_by_project_and_name(@project, params[:package], use_source:           false,
                                                                             follow_multibuild:    true,
                                                                             follow_project_links: true)
    rescue Package::UnknownObjectError
      redirect_to project_show_path(@project.to_param),
                  error: "Couldn't find package '#{params[:package]}' in " \
                         "project '#{@project.to_param}'. Are you sure it exists?"
      return false
    end

    # package is nil for remote projects
    if @package && !@package.check_source_access?
      redirect_to package_show_path(project: @project.name, package: @package.name),
                  error: 'Could not access build log'
      return false
    end

    @can_modify = User.current.can_modify_project?(@project) || User.current.can_modify_package?(@package)

    # for remote and multibuild / local link packages
    @package = params[:package] if @package.try(:name) != params[:package]

    true
  end
end
