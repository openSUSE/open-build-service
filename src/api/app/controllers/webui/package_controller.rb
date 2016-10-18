require 'open-uri'
require 'project'

class Webui::PackageController < Webui::WebuiController

  include Webui::HasComments
  include ParsePackageDiff
  include Webui::WebuiHelper
  include Webui::PackageHelper
  include Escaper
  include Webui::LoadBuildresults
  include Webui::RequiresProject
  include Webui::ManageRelationships
  include BuildLogSupport
  include ERB::Util

  helper 'webui/comment'

  before_filter :require_project, :except => [:submit_request, :devel_project]
  before_filter :require_package, :except => [:submit_request, :save_new_link, :save_new, :devel_project ]
  # make sure it's after the require_, it requires both
  before_filter :require_login, :only => [:branch, :submit_request, :save, :save_new, :save_new_link]
  prepend_before_filter :lockout_spiders, :only => [:revisions, :dependency, :rdiff, :binary, :binaries, :requests]

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
    @expand = 1
    @expand = begin Integer(params[:expand]) rescue 1 end if params[:expand]
    @expand = 0 if @spider_bot
    @is_current_rev = false
    if set_file_details
      if @forced_unexpand.blank?
        @is_current_rev = !@revision || (@revision == @current_rev)
      else
        flash.now[:error] = "Files could not be expanded: #{@forced_unexpand}"
      end
    elsif @revision_parameter
      flash[:error] = "No such revision: #{@revision_parameter}"
      redirect_back_or_to :controller => 'package', :action => 'show', :project => @project, :package => @package and return
    end

    sort_comments(@package.comments)

    @requests = []
    # TODO!!!
    #BsRequest.list({:states => %w(review), :reviewstates => %w(new), :roles => %w(reviewer), :project => @project.name, :package => @package.name}) +
    #BsRequest.list({:states => %w(new), :roles => %w(target), :project => @project.name, :package => @package.name})
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
    @arch = params[:arch]
    @repository = params[:repository]
    @drepository = params[:drepository]
    @dproject = params[:dproject]
    # Ensure it really is just a file name, no '/..', etc.
    @filename = File.basename(params[:filename])
    @fileinfo = Fileinfo.find(:project => params[:dproject], :package => '_repository', :repository => params[:drepository], :arch => @arch,
      :filename => params[:dname], :view => 'fileinfo_ext')
    @durl = nil
    unless @fileinfo # avoid displaying an error for non-existing packages
      redirect_back_or_to(:action => 'binary', :project => params[:project], :package => params[:package], :repository => @repository, :arch => @arch, :filename => @filename)
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
      @fileinfo = Fileinfo.find(:project => @project, :package => @package, :repository => @repository, :arch => @arch,
        :filename => @filename, :view => 'fileinfo_ext')
    rescue ActiveXML::Transport::ForbiddenError => e
      flash[:error] = "File #{@filename} can not be downloaded from #{@project}: #{e.summary}"
    end
    unless @fileinfo
      flash[:error] = "File \"#{@filename}\" could not be found in #{@repository}/#{@arch}"
      redirect_to :controller => 'package', :action => :binaries, :project => @project,
        :package => @package, :repository => @repository, :nextstatus => 404
      return
    end
    repo = Repository.find_by_project_and_repo_name(@project.to_s, @repository.to_s)
    @durl = repo.download_url_for_package(@package, @arch, @filename)
    if @durl and not file_available?( @durl )
      # ignore files not available
      @durl = nil
    end
    unless User.current.is_nobody? or @durl
      # only use API for logged in users if the mirror is not available
      @durl = rpm_url( @project, @package, @repository, @arch, @filename )
    end
    logger.debug "accepting #{request.accepts.join(',')} format:#{request.format}"
    # little trick to give users eager to download binaries a single click
    if request.format != Mime::HTML and @durl
      redirect_to @durl
      return
    end
  end

  def binaries
    required_parameters :repository
    @repository = params[:repository]
    begin
    @buildresult = Buildresult.find_hashed(:project => @project, :package => @package,
      :repository => @repository, :view => %w(binarylist status))
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.message
      redirect_back_or_to :controller => 'package', :action => 'show', :project => @project, :package => @package and return
    end
    unless @buildresult
      flash[:error] = "Package \"#{@package}\" has no build result for repository #{@repository}"
      redirect_to :controller => 'package', :action => :show, :project => @project, :package => @package, :nextstatus => 404 and return
    end
  end

  def users
    @users = [@project.api_obj.users, @package.users].flatten.uniq
    @groups = [@project.api_obj.groups, @package.groups].flatten.uniq
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
      redirect_to :action => :show, :project => @project.name, :package => @package.name and return
    end
    @lastrev = @package.rev.to_i
    @lastrev = params[:rev].to_i if params[:rev]
    if params[:showall]
      @revisions = (1..@lastrev).to_a.reverse
    else
      if @lastrev < 21
        @revisions = (1..@lastrev).to_a.reverse
      else
        @revisions = []
        @lastrev.downto(@lastrev-19) { |n| @revisions << n }
      end
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
    if lt = @package.backend_package.links_to
      @tprj = lt.project.name # fill in from link
      @tpkg = lt.name
    end
    @tprj = params[:targetproject] if params[:targetproject] # allow to override by parameter
    @tpkg = params[:targetpackage] if params[:targetpackage] # allow to override by parameter

    render_dialog
  end

  def submit_request
    required_parameters :project, :package
    if params[:targetproject].blank?
      flash[:error] = 'Please provide a target for the submit request'
      redirect_to :action => :show, :project => params[:project], :package => params[:package] and return
    end

    req = nil
    begin
      BsRequest.transaction do
        req = BsRequest.new(state: "new")
        req.description = params[:description]

        tpkg = params[:package]
        tpkg = params[:targetpackage] unless params[:targetpackage].blank?
        opts = { source_project: params[:project],
                 source_package: params[:package],
                 target_project: params[:targetproject],
                 target_package: tpkg }
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
      redirect_to(:action => 'show', :project => params[:project], :package => params[:package]) and return
    rescue BsRequestAction::MissingAction => e
      flash[:error] = "Unable to submit, sources are unchanged"
      redirect_to(:action => 'show', :project => params[:project], :package => params[:package]) and return
    rescue Project::UnknownObjectError,
           BsRequestAction::UnknownProject,
           BsRequestAction::UnknownTargetPackage => e
      flash[:error] = "Unable to submit (missing target): #{e.message}"
      redirect_to(:action => 'show', :project => params[:project], :package => params[:package]) and return
    rescue APIException
      flash[:error] = "Unable to submit"
      redirect_to(:action => 'show', :project => params[:project], :package => params[:package]) and return
    end

    # Supersede logic has to be below addition as we need the new request id
    supersede_errors = []
    if params[:supersede]
      pending_requests = BsRequestCollection.list_ids(project: params[:targetproject], package: params[:package], states: %w(new review declined), types: %w(submit))
      pending_requests.each do |request_id|
        next if request_id == req.id # ignore newly created request
        r = BsRequest.find_by_id request_id
        next if r.nil? # unable to load
        begin
          opts = { newstate: "superseded",
                   reason: "Superseded by request #{req.id}",
                   superseded_by: req.id }
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
    flash[:notice] = "Created <a href='#{request_show_path(req.id)}'>submit request #{req.id}</a>\
                      to <a href='#{project_show_path(params[:targetproject])}'>#{params[:targetproject]}</a>
                      #{supersede_notice}"
    redirect_to(:action => 'show', :project => params[:project], :package => params[:package])
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
    return files
  end

  def set_file_details
    @forced_unexpand ||= ''

    # check source access
    return false unless @package.check_source_access?

    set_linkinfo

    begin
      @current_rev = @package.rev
      if not @revision and not @srcmd5
        # on very first page load only
        @revision = @current_rev
      end

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
        @forced_unexpand = e.summary
        @forced_unexpand = e.details if e.details
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
    serviceerror = nil
    serviceerror = @package.serviceinfo.value(:error) if @package.serviceinfo

    return true
  end
  private :set_file_details

  def add_person
    @roles = Role.local_roles
  end

  def add_group
    @roles = Role.local_roles
  end

  def find_last_req
    if @oproject and @opackage
      last_req = BsRequestAction.where(target_project: @oproject,
                                       target_package: @opackage,
                                       source_project: @package.project,
                                       source_package: @package.name).order(:bs_request_id).last
      return nil unless last_req
      last_req = last_req.bs_request
      if last_req.state != :declined
        return nil # ignore all !declined
      end
      return { id: last_req.id,
               decliner: last_req.commenter,
               when: last_req.updated_at,
               comment: last_req.comment }
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
        redirect_back_or_to package_show_path(project: @project, package: @package)
        return false
      end
    end
    return true
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
      redirect_to :action => 'show', :project => params[:project], :package => @package_name
    else
      flash[:notice] = "Failed to create package '#{@package}'"
      redirect_to :controller => 'project', :action => 'show', :project => params[:project]
    end
  end

  def check_package_name_for_new
    unless Package.valid_name? @package_name
      flash[:error] = "Invalid package name: '#{@package_name}'"
      redirect_to :controller => :project, :action => 'new_package', :project => @project
      return false
    end
    if Package.exists_by_project_and_name @project.name, @package_name
      flash[:error] = "Package '#{@package_name}' already exists in project '#{@project}'"
      redirect_to :controller => :project, :action => 'new_package', :project => @project
      return false
    end
    @project = @project.api_obj
    unless User.current.can_create_package_in? @project
      redirect_to controller: :project, action: :new_package, project: @project,
                  error: "You can't create packages in #{@project.name}"
      return false
    end
    true
  end

  def branch_dialog
    render_dialog
  end

  def branch
    begin
      path = "/source/#{CGI.escape(params[:project])}/#{CGI.escape(params[:package])}?cmd=branch"
      result = ActiveXML::Node.new(frontend.transport.direct_http( URI(path), :method => 'POST', :data => ''))
      result_project = result.find_first( "/status/data[@name='targetproject']" ).text
      result_package = result.find_first( "/status/data[@name='targetpackage']" ).text
    rescue ActiveXML::Transport::Error => e
      message = e.summary
      if e.code == 'double_branch_package'
        flash[:notice] = 'You already branched the package and got redirected to it instead'
        bprj, bpkg = message.split('exists: ')[1].split('/', 2) # Hack to find out branch project / package
        redirect_to :controller => 'package', :action => 'show', :project => bprj, :package => bpkg and return
      else
        flash[:error] = message
        redirect_to :controller => 'package', :action => 'show', :project => params[:project], :package => params[:package] and return
      end
    end
    flash[:success] = "Branched package #{@project} / #{@package}"
    redirect_to :controller => 'package', :action => 'show',
      :project => result_project, :package => result_package and return
  end


  def save_new_link
    @linked_project = params[:linked_project].strip
    @linked_package = params[:linked_package].strip
    @target_package = params[:target_package].strip
    @revision       = nil
    @current_revision = true if params[:current_revision]

    unless Package.valid_name? @linked_package
      flash[:error] = "Invalid package name: '#{@linked_package}'"
      redirect_to :controller => :project, :action => 'new_package_branch', :project => params[:project] and return
    end

    unless Project.valid_name? @linked_project
      flash[:error] = "Invalid project name: '#{@linked_project}'"
      redirect_to :controller => :project, :action => 'new_package_branch', :project => params[:project] and return
    end

    begin
      # just as existence check
      Package.get_by_project_and_name(@linked_project, @linked_package)
    rescue APIException
      flash[:error] = "Unable to find package '#{@linked_package}' in project '#{@linked_project}'."
      redirect_to :controller => :project, :action => 'new_package_branch', :project => @project and return
    end

    @target_package = @linked_package if @target_package.blank?
    unless Package.valid_name? @target_package
      flash[:error] = "Invalid target package name: '#{@target_package}'"
      redirect_to :controller => :project, :action => 'new_package_branch', :project => @project and return
    end
    if Package.exists_by_project_and_name @project.name, @target_package
      flash[:error] = "Package '#{@target_package}' already exists in project '#{@project}'"
      redirect_to :controller => :project, :action => 'new_package_branch', :project => @project and return
    end

    dirhash = Package.dir_hash(@linked_project, @linked_package)
    revision = dirhash['xsrcmd5'] || dirhash['rev']
    unless revision
      flash[:error] = "Unable to branch package '#{@target_package}', it has no source revision yet"
      redirect_to :controller => :project, :action => 'new_package_branch', :project => @project and return
    end

    @revision = revision if @current_revision

    logger.debug "link params doing branch: #{@linked_project}, #{@linked_package}"
    begin
      path = Package.source_path(@linked_project, @linked_package, nil, { cmd: :branch, target_project: @project.name, target_package: @target_package})
      path += "&rev=#{CGI.escape(@revision)}" if @revision
      frontend.transport.direct_http( URI(path), :method => 'POST', :data => '')
      flash[:success] = "Branched package #{@project.name} / #{@target_package}"
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.summary
    end

    redirect_to :controller => 'package', :action => 'show', :project => @project, :package => @target_package
  end

  def save
    unless User.current.can_modify_package? @package
      redirect_to :action => 'show', :project => params[:project], :package => params[:package], error: 'No permission to save'
      return
    end
    @package.title = params[:title]
    @package.description = params[:description]
    if @package.save
      flash[:notice] = "Package data for '#{@package.name}' was saved successfully"
    else
      flash[:notice] = "Failed to save package '#{@package.name}'"
    end
    redirect_to :action => 'show', :project => params[:project], :package => params[:package]
  end

  def delete_dialog
    render_dialog
  end

  def remove
    begin
      FrontendCompat.new.delete_package :project => @project, :package => @package
      flash[:notice] = "Package '#{@package}' was removed successfully from project '#{@project}'"
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.summary
    end
    redirect_to :controller => 'project', :action => 'show', :project => @project
  end

  def add_file
    set_file_details
  end

  def valid_file_name? name
    name.present? && name =~ %r{^[^\/]+$}
  end

  def save_file
    unless User.current.can_modify_package? @package
      redirect_to :back, error: "You're not allowed to modify #{@package.name}"
      return
    end

    file = params[:file]
    file_url = params[:file_url]
    filename = params[:filename]

    if file.present?
      # we are getting an uploaded file
      filename = file.original_filename if filename.blank?

      unless valid_file_name?(filename)
        flash[:error] = "'#{filename}' is not a valid filename."
        redirect_back_or_to :action => 'add_file', :project => params[:project], :package => params[:package]
        return
      end

      begin
        @package.save_file file: file, filename: filename
      rescue ActiveXML::Transport::Error => e
        flash[:error] = e.summary
        redirect_back_or_to :action => 'add_file', :project => params[:project], :package => params[:package]
        return
      end
    elsif file_url.present?
      # we have a remote file uri
      return unless add_file_url(file_url, filename)
    else
      return unless add_file_filename(filename)
    end

    flash[:success] = "The file #{filename} has been added."
    redirect_to :action => :show, :project => @project, :package => @package
  end

  def add_file_filename(filename)
    if filename.blank?
      flash[:error] = 'No file or URI given.'
      redirect_back_or_to :action => 'add_file', :project => params[:project], :package => params[:package]
      return false
    else
      unless valid_file_name?(filename)
        flash[:error] = "'#{filename}' is not a valid filename."
        redirect_back_or_to :action => 'add_file', :project => params[:project], :package => params[:package]
        return false
      end
      begin
        @package.save_file filename: filename
      rescue ActiveXML::Transport::Error => e
        flash[:error] = e.summary
        redirect_back_or_to :action => 'add_file', :project => params[:project], :package => params[:package]
        return false
      end
    end
    true
  end

  def add_file_url(file_url, filename=nil)
    @services = Service.find(project: @project, package: @package.name)
    unless @services
      @services = Service.new(project: @project, package: @package.name)
    end
    @services.addDownloadURL(file_url, filename) # detects automatically git://, src.rpm formats
    unless @services.save
      flash[:error] = "Failed to add file from URL '#{file_url}'. -> #{e.class}"
      redirect_back_or_to :action => 'add_file', :project => params[:project], :package => params[:package]
      return false
    end
    true
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
    redirect_to :action => :show, :project => @project, :package => @package
  end

  def view_file
    @filename = params[:filename] || params[:file] || ''
    if Package.is_binary_file?(@filename) # We don't want to display binary files
      flash[:error] = "Unable to display binary file #{@filename}"
      redirect_back_or_to :action => :show, :project => @project, :package => @package and return
    end
    @rev = params[:rev]
    @expand = params[:expand]
    @addeditlink = false
    if User.current.can_modify_package?(@package) && @rev.blank?
      begin
        files = package_files(@rev, @expand)
      rescue ActiveXML::Transport::Error => e
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
    rescue ActiveXML::Transport::NotFoundError => e
      flash[:error] = "File not found: #{@filename}"
      redirect_to :action => :show, :package => @package, :project => @project and return
    rescue ActiveXML::Transport::Error => e
      flash[:error] = "Error: #{e}"
      redirect_back_or_to :action => :show, :project => @project, :package => @package and return
    end
    if @spider_bot
      render :template => 'webui/package/simple_file_view' and return
    end
  end

  def fetch_from_params(*arr)
    opts = {}
    arr.each do |k|
      opts[k] = params[k] if params[k].present?
    end
    opts
  end

  def save_modified_file
    check_ajax
    required_parameters :project, :package, :filename, :file
    project = params[:project]
    package = params[:package]
    filename = params[:filename]
    params[:file].gsub!( /\r\n/, "\n" )
    begin
      frontend.put_file(params[:file], :project => project, :package => package, :filename => filename, :comment => params[:comment])
    rescue Timeout::Error => e
      render json: { error: 'Timeout when saving file. Please try again.'
      }, status: 400
      return
    rescue ActiveXML::Transport::Error => e
      render json: { error: e.summary }, status: 400
      return
    end
    render json: { status: 'ok' }
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
    if @package and not @package.check_source_access?
      flash[:error] = 'Could not access build log'
      redirect_to :action => :show, :project => @project.name, :package => @package.name and return
    end
    @arch = params[:arch]
    @repo = params[:repository]
    @offset = 0

    set_job_status
  end

  def set_initial_offset
    # Do not start at the beginning long time ago
    begin
      size = get_size_of_log(@project, @package, @repo, @arch)
      logger.debug('log size is %d' % size)
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

    set_initial_offset if @offset == 0

    begin
      @log_chunk = get_log_chunk( @project, @package, @repo, @arch, @offset, @offset + @maxsize)

      if( @log_chunk.length == 0 )
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
    params[:redirect] = 'live_build_log'
    api_cmd('abortbuild', params)
  end


  def trigger_rebuild
    api_cmd('rebuild', params)
  end

  def wipe_binaries
    api_cmd('wipe', params)
  end

  def devel_project
    check_ajax
    required_parameters :package, :project
    tgt_pkg = Package.find_by_project_and_name( params[:project], params[:package] )
    if tgt_pkg and tgt_pkg.develpackage
      render text: tgt_pkg.develpackage.project
    else
      render text: ''
    end
  end

  def api_cmd(cmd, params)
    options = {}
    options[:arch] = params[:arch] if params[:arch]
    options[:repository] = params[:repo] if params[:repo]
    options[:project] = @project.to_s
    options[:package] = @package.to_s

    begin
      frontend.cmd cmd, options
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.summary
      redirect_to :action => :show, :project => @project, :package => @package and return
    end

    logger.debug( "Triggered #{cmd} for #{@project}/#{@package}, options=#{options.inspect}" )
    @message = "Triggered #{cmd} for #{@project}/#{@package}."
    controller = 'package'
    action = 'show'
    if  params[:redirect] == 'monitor'
      controller = 'project'
      action = 'monitor'
    end

    unless request.xhr?
      # non ajax request:
      flash[:notice] = @message
      redirect_to :controller => controller, :action => action,
        :project => @project, :package => @package
    else
      # ajax request - render default view: in this case 'trigger_rebuild.rjs'
      return
    end
  end
  private :api_cmd

  def import_spec
    all_files = package_files
    all_files.each do |file|
      @specfile_name = file[:name] if file[:name].end_with?('.spec')
    end
    if @specfile_name.blank?
      render json: {} and return
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
    render :partial => 'buildstatus'
  end

  def rpmlint_result
    check_ajax
    @repo_list, @repo_arch_hash = [], {}
    @buildresult = Buildresult.find_hashed(:project => @project.to_param, :package => @package.to_param, :view => 'status')
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
      render :text => res, content_type: 'text/html'
    rescue ActiveXML::Transport::NotFoundError
      render :text => 'No rpmlint log'
    end
  end

  def meta
    @meta = @package.render_xml
  end

  def save_meta
    begin
      frontend.put_file(params[:meta], :project => @project, :package => @package, :filename => '_meta')
    rescue ActiveXML::Transport::Error => e
      message = e.summary
      flash[:error] = message
      @meta = params[:meta]
      render :text => message, :status => 400, :content_type => 'text/plain'
      return
    end

    flash[:notice] = 'Config successfully saved'
    render :text => 'Config successfully saved', :content_type => 'text/plain'
  end

  def edit
  end

  def repositories
    @flags = @package.expand_flags
  end

  def change_flag
    check_ajax
    required_parameters :cmd, :flag
    frontend.source_cmd params[:cmd], project: @project, package: @package, repository: params[:repository], arch: params[:arch], flag: params[:flag], status: params[:status]
    @flags = @package.expand_flags[params[:flag]]
  end

  private

  def file_available? url, max_redirects=5
    uri = URI.parse( url )
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 15
    http.read_timeout = 15
    logger.debug "Checking url: #{url}"
    begin
      response =  http.head uri.path
      if response.code.to_i == 302 and response['location'] and max_redirects > 0
        return file_available? response['location'], (max_redirects - 1)
      end
      return response.code.to_i == 200 ? true : false
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
        @package = Package.get_by_project_and_name( @project.to_param, params[:package], use_source: false, follow_project_links: true )
      rescue APIException # why it's not found is of no concern :)
      end
    end

    render_missing_package unless @package
  end

  def render_missing_package
    unless request.xhr?
      flash[:error] = "Package \"#{params[:package]}\" not found in project \"#{params[:project]}\""
      redirect_to :controller => 'project', :action => 'show', :project => @project, :nextstatus => 404
    else
      render :text => "Package \"#{h(params[:package])}\" not found in project \"#{h(params[:project])}\"", :status => 404 and return
    end
  end

  def load_buildresults
    @buildresult = Buildresult.find_hashed( :project => @project, :package => @package.to_param, :view => 'status')
    if @buildresult.blank?
      @buildresult = Array.new
      return
    end
    fill_status_cache

    newr = Hash.new
    @buildresult.elements('result').sort {|a,b| a['repository'] <=> b['repository']}.each do |result|
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
