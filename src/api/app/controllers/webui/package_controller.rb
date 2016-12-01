require 'open-uri'
require 'project'

class Webui::PackageController < Webui::WebuiController
  require_dependency 'opensuse/validator'
  include Webui::HasComments
  include ParsePackageDiff
  include Webui::PackageHelper
  include Escaper
  include Webui::LoadBuildresults
  include Webui::ManageRelationships
  include BuildLogSupport

  helper 'webui/comment'

  before_action :set_project, only: [:show, :users, :linking_packages, :dependency, :binary, :binaries,
                                     :requests, :statistics, :commit, :revisions, :submit_request_dialog,
                                     :add_person, :add_group, :rdiff, :wizard_new, :wizard, :save_new,
                                     :branch_dialog, :branch, :save_new_link, :save, :delete_dialog,
                                     :remove, :add_file, :save_file, :remove_file, :save_person,
                                     :save_group, :remove_role, :view_file,
                                     :abort_build, :trigger_rebuild, :trigger_services,
                                     :wipe_binaries, :buildresult, :rpmlint_result, :rpmlint_log, :meta,
                                     :save_meta, :attributes, :edit, :import_spec, :files, :comments]

  before_action :require_package, only: [:show, :linking_packages, :dependency, :binary, :binaries,
                                         :requests, :statistics, :commit, :revisions, :submit_request_dialog,
                                         :add_person, :add_group, :rdiff, :wizard_new, :wizard,
                                         :branch_dialog, :branch, :save, :delete_dialog,
                                         :remove, :add_file, :save_file, :remove_file, :save_person,
                                         :save_group, :remove_role, :view_file,
                                         :abort_build, :trigger_rebuild, :trigger_services,
                                         :wipe_binaries, :buildresult, :rpmlint_result, :rpmlint_log, :meta,
                                         :attributes, :edit, :import_spec, :files, :comments, :users,
                                         :save_comment]

  # make sure it's after the require_, it requires both
  before_action :require_login, except: [:show, :linking_packages, :linking_packages, :dependency,
                                         :binary, :binaries, :users, :requests, :statistics, :commit,
                                         :revisions, :rdiff, :wizard_new, :view_file, :live_build_log,
                                         :update_build_log, :devel_project, :buildresult, :rpmlint_result,
                                         :rpmlint_log, :meta, :attributes, :files]

  prepend_before_action :lockout_spiders, only: [:revisions, :dependency, :rdiff, :binary, :binaries, :requests]

  def show
    if lockout_spiders
      params.delete(:rev)
      params.delete(:srcmd5)
    end

    @srcmd5   = params[:srcmd5]
    @revision_parameter = params[:rev]

    @bugowners_mail = (@package.bugowner_emails + @project.api_obj.bugowner_emails).uniq
    @revision = params[:rev]
    @failures = 0
    load_buildresults
    set_linking_packages

    if @spider_bot
      @expand = 0
    elsif params[:expand]
      @expand = params[:expand].to_i
    else
      @expand = 1
    end

    @is_current_rev = false
    if set_file_details
      if @forced_unexpand.blank?
        @is_current_rev = !@revision || (@revision == @current_rev)
      else
        flash.now[:error] = "Files could not be expanded: #{@forced_unexpand}"
      end
    elsif @revision_parameter
      flash[:error] = "No such revision: #{@revision_parameter}"
      redirect_back(fallback_location: {controller: :package, action: :show, project: @project, package: @package})
      return
    end

    @comments = @package.comments
    @requests = []
    @services = Service.find(project: @project.name, package: @package.name)
  end

  def main_object
    @package # used by mixins
  end

  def set_linking_packages
    @linking_packages = @package.linking_packages
  end

  def linking_packages
    set_linking_packages
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
      unless project_repositories.include?(params[repo_key])
        flash[:error] = "Repository '#{params[repo_key]}' is invalid."
        redirect_back(fallback_location: project_show_path(project: params[:dproject]))
        # rubocop:disable Lint/NonLocalExitFromIterator
        return
        # rubocop:enable Lint/NonLocalExitFromIterator
      end
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
    unless @fileinfo # avoid displaying an error for non-existing packages
      redirect_back(fallback_location: { action: :binary, project: params[:project], package: params[:package],
                                         repository: @repository, arch: @arch, filename: @filename })
    end
  end

  def statistics
    required_parameters :arch, :repository
    @arch = params[:arch]
    @repository = params[:repository]
    @statistics = nil
    begin
      @statistics = Statistic.find_hashed( project: @project, package: @package, repository: @repository, arch: @arch )
    rescue ActiveXML::Transport::ForbiddenError
    end
    logger.debug "Statis #{@statistics.inspect}"
    unless @statistics
      flash[:error] = "No statistics of a successful build could be found in #{@repository}/#{@arch}"
      redirect_to controller: 'package', action: :binaries, project: @project,
                  package: @package, repository: @repository, nextstatus: 404
      return
    end
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
    @durl = repo.download_url_for_package(@package, @arch, @filename)
    @durl = nil if @durl && !file_available?(@durl) # ignore files not available
    unless User.current.is_nobody? || @durl
      # only use API for logged in users if the mirror is not available
      @durl = rpm_url( @project, @package, @repository, @arch, @filename )
    end
    logger.debug "accepting #{request.accepts.join(',')} format:#{request.format}"
    # little trick to give users eager to download binaries a single click
    if request.format != Mime::HTML && @durl
      redirect_to @durl
      return
    end
  end

  def binaries
    required_parameters :repository
    @repository = params[:repository]
    begin
    @buildresult = Buildresult.find_hashed(project: @project, package: @package,
      repository: @repository, view: %w(binarylist status))
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.message
      redirect_back(fallback_location: { controller: :package, action: :show, project: @project, package: @package })
      return
    end
    unless @buildresult
      flash[:error] = "Package \"#{@package}\" has no build result for repository #{@repository}"
      redirect_to controller: :package, action: :show, project: @project, package: @package, nextstatus: 404
      return
    end
  end

  def users
    @users = [@project.users, @package.users].flatten.uniq
    @groups = [@project.groups, @package.groups].flatten.uniq
    @roles = Role.local_roles
  end

  def requests
    @default_request_type = params[:type] if params[:type]
    @default_request_state = params[:state] if params[:state]
  end

  def commit
    required_parameters :revision
    render partial: 'commit_item', locals: {rev: params[:revision] }
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
      @lastrev.downto(@lastrev-19) { |n| @revisions << n }
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
        req = BsRequest.new(state: "new")
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
      flash[:error] = "Unable to submit, sources are unchanged"
    rescue Project::UnknownObjectError,
           BsRequestAction::UnknownProject,
           BsRequestAction::UnknownTargetPackage => e
      flash[:error] = "Unable to submit (missing target): #{e.message}"
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
            newstate:      "superseded",
            reason:        "Superseded by request #{req.number}",
            superseded_by: req.number
          }
          r.change_state(opts)
        rescue APIException => e
          supersede_errors << "#{e.message}"
        end
      end
    end

    if supersede_errors.any?
      supersede_notice = "Superseding failed: "
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
    if lt
      @linkinfo = { package: lt, error: @package.backend_package.error }
      if lt.backend_package.verifymd5 != @package.backend_package.verifymd5
        @linkinfo[:diff] = true
      end
    end
  end

  def package_files( rev = nil, expand = nil )
    files = []
    p = {}
    p[:project] = @package.project.name
    p[:package] = @package.name
    p[:expand]  = expand  if expand
    p[:rev]     = rev     if rev
    dir = Directory.find(p)
    return files unless dir
    @serviceinfo = dir.find_first(:serviceinfo)
    dir.each(:entry) do |entry|
      file = Hash[*[:name, :size, :mtime, :md5].map {|x| [x, entry.value(x.to_s)]}.flatten]
      file[:viewable] = !Package.is_binary_file?(file[:name]) && file[:size].to_i < 2**20  # max. 1 MB
      file[:editable] = file[:viewable] && !file[:name].match(/^_service[_:]/)
      file[:srcmd5] = dir.value(:srcmd5)
      files << file
    end
    files
  end

  def set_file_details
    @forced_unexpand ||= ''

    # check source access
    return false unless @package.check_source_access?

    set_linkinfo

    begin
      @current_rev = @package.rev
      @revision = @current_rev if !@revision && !@srcmd5 # on very first page load only

      if @srcmd5
        @files = package_files(@srcmd5, @expand)
      else
        @files = package_files(@revision, @expand)
      end
    rescue ActiveXML::Transport::Error => e
      # TODO crudest hack ever!
      if e.summary == 'service in progress'
        @expand = 0
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

  def add_person
    @roles = Role.local_roles
  end

  def add_group
    @roles = Role.local_roles
  end

  def find_last_req
    if @oproject && @opackage
      last_req = BsRequestAction.where(target_project: @oproject,
                                       target_package: @opackage,
                                       source_project: @package.project,
                                       source_package: @package.name).order(:bs_request_id).last
      return nil unless last_req
      last_req = last_req.bs_request
      if last_req.state != :declined
        return nil # ignore all !declined
      end
      return {
        id:       last_req.number,
        decliner: last_req.commenter,
        when:     last_req.updated_at,
        comment:  last_req.comment
      }
    end
    return nil
  end

  class DiffError < APIException
  end

  def get_diff(path)
    begin
      @rdiff = ActiveXML.backend.direct_http URI(path + '&expand=1'), method: 'POST', timeout: 10
    rescue ActiveXML::Transport::Error => e
      flash[:error] = 'Problem getting expanded diff: ' + e.summary
      begin
        @rdiff = ActiveXML.backend.direct_http URI(path + '&expand=0'), method: 'POST', timeout: 10
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

    query = {'cmd' => 'diff', 'view' => 'xml', 'withissues' => 1}
    [:orev, :opackage, :oproject, :linkrev, :olinkrev].each do |k|
      query[k] = params[k] unless params[k].blank?
    end
    query[:rev] = @rev if @rev
    return unless get_diff(@package.source_path + "?#{query.to_query}")

    # we only look at [0] because this is a generic function for multi diffs - but we're sure we get one
    filenames = sorted_filenames_from_sourcediff(@rdiff)[0]
    @files = filenames['files']
    @filenames = filenames['filenames']
  end

  def save_new
    @package_name = params[:name]
    @package_title = params[:title]
    @package_description = params[:description]

    return unless check_package_name_for_new

    @package = @project.packages.build( name: @package_name )
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

  def branch_dialog
    render_dialog
  end

  def branch
    authorize @package, :branch?
    # FIXME: This authorize isn't in sync with the permission checks of BranchPackage. And the created
    #        project might differ from the one we check here.
    authorize Project.new(name: User.current.branch_project_name(@project)), :create?

    branched_package = BranchPackage.new(project: @project.name, package: @package.name).branch
    created_project_name = branched_package[:data][:targetproject]
    created_package_name = branched_package[:data][:targetpackage]

    Event::BranchCommand.create(project: @project.name, package: @package.name,
                                targetproject: created_project_name, targetpackage: created_package_name,
                                user: User.current.login)
    redirect_to(package_show_path(project: created_project_name, package: created_package_name),
                notice: "Successfully branched package")
  rescue BranchPackage::DoubleBranchPackageError
      redirect_to(package_show_path(project: User.current.branch_project_name(@project), package: @package),
                  notice: 'You have already branched this package')
  rescue APIException => e
      redirect_back(fallback_location: root_path, error: e.message)
  end

  def save_new_link
    # Are we linking a package from a remote instance?
    # Then just try, the remote instance will handle checking for existence
    # authorization etc.
    if Project.find_remote_project(params[:linked_project])
      source_project_name = params[:linked_project]
      source_package_name = params[:linked_package]
    # If we are linking a local package we have to do it ourselves
    else
      source_package = Package.find_by_project_and_name(params[:linked_project], params[:linked_package])
      unless source_package
        redirect_back(fallback_location: root_path, error: "Failed to branch: Package does not exist.")
        return
      end
      authorize source_package, :branch?
      source_project_name = source_package.project.name
      source_package_name = source_package.name
    end
    revision = nil
    unless params[:current_revision].blank?
      dirhash = Directory.hashed(project: source_project_name, package: source_package_name)
      if dirhash['error']
        redirect_back(fallback_location: root_path, error: dirhash['error'])
      end
      revision = dirhash['xsrcmd5'] || dirhash['rev']
      unless revision
        redirect_back(fallback_location: root_path, error: "Failed to branch: Package has no source revision yet")
        return
      end
    end

    params[:target_package] = source_package_name if params[:target_package].blank?

    begin
      BranchPackage.new(project: source_project_name,
                        package: source_package_name,
                        target_project: @project.name,
                        target_package: params[:target_package],
                        rev: revision).branch
      Event::BranchCommand.create(project: source_project_name, package: source_package_name,
                                  targetproject: @project.name, targetpackage: params[:target_package],
                                  user: User.current.login)
      redirect_to(package_show_path(project: @project, package: params[:target_package]),
                  notice: "Successfully branched package")
    rescue BranchPackage::DoubleBranchPackageError
      redirect_to(package_show_path(project: @project, package: params[:target_package]),
                  notice: 'You have already branched this package')
    rescue => e
      redirect_back(fallback_location: root_path, error: "Failed to branch: #{e.message}")
    end
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
    else
      flash[:notice] = "Failed to save package '#{@package.name}'"
    end
    redirect_to action: :show, project: params[:project], package: params[:package]
  end

  def delete_dialog
    render_dialog
  end

  def remove
    authorize @package, :destroy?

    # Don't check weak dependencies if we force
    unless params[:force]
      @package.check_weak_dependencies?
    end
    if @package.errors.empty?
      @package.destroy
      redirect_to(project_show_path(@project), notice: "Package was successfully removed.")
    else
      redirect_to(package_show_path(project: @project, package: @package),
                  notice: "Package can't be removed: #{@package.errors.full_messages.to_sentence}")
    end
  end

  def trigger_services
    begin
      Suse::Backend.post "/source/#{URI.escape(@project.name)}/#{URI.escape(@package.name)}?cmd=runservice&user=#{User.current}"
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
      else
        # No file is provided so we just create an empty new file (touch)
        if filename.present?
          @package.save_file(filename: filename)
        else
          errors << 'No file or URI given'
        end
      end
    rescue ActiveXML::Transport::Error => e
      errors << Xmlhash::XMLHash.new(error: e.summary)[:error]
    rescue APIException, StandardError => e
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
      return
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
    if @spider_bot
      render template: 'webui/package/simple_file_view'
      return
    end
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
      jobstatus = get_job_status( @project, @package, @repo, @arch )
      unless jobstatus.blank?
        js = Xmlhash.parse(jobstatus)
        @workerid = js.get('workerid')
        @buildtime = Time.now.to_i - js.get('starttime').to_i
        ld = js.get('lastduration')
        @percent = (@buildtime * 100) / ld.to_i unless ld.blank?
      end
    rescue
      @workerid = nil
      @buildtime = nil
    end
  end

  def live_build_log
    required_parameters :arch, :repository

    if Project.exists_by_name(params[:project])
      @project = Project.get_by_name(params[:project])
    else
      flash[:error] = "Couldn't find project '#{params[:project]}'. Are you sure it still exists?"
      redirect_back(fallback_location: root_path)
      return
    end

    begin
      @package = Package.get_by_project_and_name(@project,
                                                 params[:package],
                                                 {use_source:           false,
                                                  follow_multibuild:    true,
                                                  follow_project_links: true})
    rescue Package::UnknownObjectError
      flash[:error] = "Couldn't find package '#{params[:package]}' in project '#{@project.to_param}'. Are you sure it exists?"
      redirect_to project_show_path(@project.to_param)
      return
    end

    if @package && !@package.check_source_access?
      flash[:error] = 'Could not access build log'
      redirect_to action: :show, project: @project.name, package: @package.name
      return
    end

    @build_container = params[:package] # for remote and multibuild package
    @package ||= params[:package] # for remote case
    @arch = params[:arch]
    @repo = params[:repository]
    @offset = 0

    set_job_status
  end

  def set_initial_offset
    # Do not start at the beginning long time ago
    begin
      size = get_size_of_log(@project, @package, @repo, @arch)
      logger.debug("log size is #{size}")
      @offset = size - 32 * 1024
      @offset = 0 if @offset < 0
    rescue => e
      logger.error "Got #{e.class}: #{e.message}; returning empty log."
    end
  end

  def update_build_log
    check_ajax

    @project = params[:project]
    @package = params[:package]
    @arch = params[:arch]
    @repo = params[:repository]
    @initial = params[:initial]
    @offset = params[:offset].to_i
    @finished = false
    @maxsize = 1024 * 64

    set_initial_offset if @offset.zero?

    begin
      @log_chunk = get_log_chunk(@project, @package, @repo, @arch, @offset, @offset + @maxsize)

      if @log_chunk.length.zero?
        @finished = true
      else
        @offset += ActiveXML::backend.last_body_length
      end

    rescue Timeout::Error, IOError
      @log_chunk = ''

    rescue ActiveXML::Transport::Error => e
      if e.summary =~ %r{Logfile is not that big}
        @log_chunk = ''
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
      redirect_to controller: :package, action: :show, project: @project, package: @package
    else
      flash[:error] = "Error while triggering abort build for #{@project.name}/#{@package.name}: #{@package.errors.full_messages.to_sentence}."
      redirect_to controller: :package, action: :live_build_log, project: @project, package: @package, repository: params[:repository]
    end
  end

  def trigger_rebuild
    authorize @package, :update?

    if @package.rebuild(params)
      flash[:notice] = "Triggered rebuild for #{@project.name}/#{@package.name} successfully."
      redirect_to controller: :package, action: :show, project: @project, package: @package
    else
      flash[:error] = "Error while triggering rebuild for #{@project.name}/#{@package.name}: #{@package.errors.full_messages.to_sentence}."
      redirect_to controller: :package, action: :binaries, project: @project, package: @package, repository: params[:repository]
    end
  end

  def wipe_binaries
    authorize @package, :update?

    if @package.wipe_binaries(params)
      flash[:notice] = "Triggered wipe binaries for #{@project.name}/#{@package.name} successfully."
      redirect_to controller: :package, action: :show, project: @project, package: @package
    else
      flash[:error] = "Error while triggering wipe binaries for #{@project.name}/#{@package.name}: #{@package.errors.full_messages.to_sentence}."
      redirect_to controller: :package, action: :binaries, project: @project, package: @package, repository: params[:repository]
    end
  end

  def devel_project
    check_ajax
    required_parameters :package, :project
    tgt_pkg = Package.find_by_project_and_name( params[:project], params[:package] )
    if tgt_pkg && tgt_pkg.develpackage
      render plain: tgt_pkg.develpackage.project
    else
      render plain: ''
    end
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
    load_buildresults
    render partial: 'buildstatus'
  end

  def rpmlint_result
    check_ajax
    @repo_list, @repo_arch_hash = [], {}
    @buildresult = Buildresult.find_hashed(project: @project.to_param, package: @package.to_param, view: 'status')
    repos = [] # Temp var
    @buildresult.elements('result') do |result|
      hash_key = valid_xml_id(elide(result.value('repository'), 30))
      @repo_arch_hash[hash_key] ||= []
      @repo_arch_hash[hash_key] << result['arch']
      repos << result.value('repository')
    end if @buildresult
    repos.uniq.each do |repo_name|
      @repo_list << [repo_name, valid_xml_id(elide(repo_name, 30))]
    end
    if @repo_list.empty?
      render partial: 'no_repositories'
    else
      render partial: 'rpmlint_result', locals: {index: params[:index]}
    end
  end

  def get_rpmlint_log(project, package, repository, architecture)
    path = "/build/#{pesc project}/#{pesc repository}/#{pesc architecture}/#{pesc package}/rpmlint.log"
    ActiveXML::backend.direct_http(URI(path), timeout: 500)
  end

  def rpmlint_log
    required_parameters :project, :package, :repository, :architecture
    begin
      rpmlint_log = get_rpmlint_log(params[:project], params[:package], params[:repository], params[:architecture])
      rpmlint_log.encode!(xml: :text)
      res = ''
      rpmlint_log.lines.each do |line|
        if line.match(/\w+(?:\.\w+)+: W: /)
          res += "<span style=\"color: olive;\">#{line}</span>"
        elsif line.match(/\w+(?:\.\w+)+: E: /)
          res += "<span style=\"color: red;\">#{line}</span>"
        else
          res += line
        end
      end
      render text: res, content_type: 'text/html'
    rescue ActiveXML::Transport::NotFoundError
      render text: 'No rpmlint log'
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
          errors << "project name in xml data does not match resource path component"
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
      flash.now[:success] = "The Meta file has been successfully saved."
      render layout: false, partial: 'layouts/webui/flash', object: flash
    else
      flash.now[:error] = "Error while saving the Meta file: #{errors.compact.join("\n")}."
      render layout: false, status: 400, partial: 'layouts/webui/flash', object: flash
    end
  end

  def edit
  end

  private

  def file_available? url, max_redirects = 5
    begin
      logger.debug "Checking url: #{url}"
      uri = URI.parse( url )
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 15
      http.read_timeout = 15
      response =  http.head uri.path
      if response.code.to_i == 302 && response['location'] && max_redirects > 0
        return file_available? response['location'], (max_redirects - 1)
      end
      return response.code.to_i == 200
    rescue Object => e
      logger.error "Error in checking for file #{url}: #{e.message}"
      return false
    end
  end

  def require_package
    required_parameters :package
    params[:rev], params[:package] = params[:pkgrev].split('-', 2) if params[:pkgrev]
    @project ||= params[:project]
    unless params[:package].blank?
      begin
        @package = Package.get_by_project_and_name( @project.to_param, params[:package],
                                                    {use_source: false, follow_project_links: true, follow_multibuild: true} )
      rescue APIException # why it's not found is of no concern :)
      end
    end

    unless @package
      flash[:error] = "Package \"#{params[:package]}\" not found in project \"#{params[:project]}\""
      redirect_to project_show_path(project: @project, nextstatus: 404)
    end
  end

  def load_buildresults
    @buildresult = Buildresult.find_hashed( project: @project, package: @package.to_param, view: 'status')
    if @buildresult.blank?
      @buildresult = Array.new
      return
    end
    fill_status_cache

    newr = Hash.new
    @buildresult.elements('result').sort {|a, b| a['repository'] <=> b['repository']}.each do |result|
      repo = result['repository']
      if result.has_key? 'status'
        newr[repo] ||= Array.new
        newr[repo] << result['arch']
      end
    end

    @buildresult = Array.new
    newr.keys.sort.each do |r|
      @buildresult << [r, newr[r].flatten.sort]
    end
  end

  def users_path
    url_for(action: :users, project: @project, package: @package)
  end

  def add_path(action)
    url_for(action: action, project: @project, role: params[:role], userid: params[:userid], package: @package)
  end
end
