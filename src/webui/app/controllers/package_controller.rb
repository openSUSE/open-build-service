require 'open-uri'
require 'project'

class PackageController < ApplicationController

  include ApplicationHelper
  include PackageHelper

  before_filter :require_project, :except => [:add_person, :create_submit,
    :edit_file, :import_spec, :rawlog, :remove_file, :remove_person,
    :remove_url, :save, :save_modified_file, :save_person,
    :set_url, :set_url_form, :update_build_log]
  before_filter :require_package, :except => [:create_submit, :edit_file, :rawlog,
    :save_modified_file, :save_new, :save_new_link, :update_build_log]

  before_filter :load_current_requests
  before_filter :require_login, :only => [:branch]
  before_filter :require_meta, :only => [:edit_meta, :meta ]

  def fill_email_hash
    @email_hash = Hash.new
    persons = [@package.each_person, @project.each_person].flatten.map{|p| p.userid.to_s}.uniq
    persons.each do |person|
      @email_hash[person] = Person.email_for_login(person)
    end
    @roles = Role.local_roles
  end
  private :fill_email_hash

  def show
    begin 
      @buildresult = find_cached(Buildresult, :project => @project, :package => @package, :view => 'status', :expires_in => 5.minutes )
    rescue => e
      logger.error "No buildresult found for #{@project} / #{@package} : #{e.message}"
    end
    if @package.bugowner
      @bugowner_mail = find_cached(Person, @package.bugowner ).email.to_s
    elsif @project.bugowner
      @bugowner_mail = find_cached(Person, @project.bugowner ).email.to_s
    end
    fill_status_cache unless @buildresult.blank?
    linking_packages
  end

  def linking_packages
    cache_string = "%s/%s_linking_packages" % [ @project, @package ]
    Rails.cache.delete(cache_string) if discard_cache?
    @linking_packages = Rails.cache.fetch( cache_string, :expires_in => 30.minutes) do
       @package.linking_packages
    end
  end

  def dependency
    @arch = params[:arch]
    @repository = params[:repository]
    @drepository = params[:drepository]
    @dproject = params[:dproject]
    @filename = params[:filename]
    @fileinfo = find_cached(Fileinfo, :project => params[:dproject], :package => '_repository', :repository => params[:drepository], :arch => @arch,
      :filename => params[:dname], :view => 'fileinfo_ext')
    @durl = nil
  end

  def binary
    required_parameters :arch, :repository, :filename
    @arch = params[:arch]
    @repository = params[:repository]
    @filename = params[:filename]
    @fileinfo = find_cached(Fileinfo, :project => @project, :package => @package, :repository => @repository, :arch => @arch,
      :filename => @filename, :view => 'fileinfo_ext')
    unless @fileinfo
      flash[:error] = "File \"#{@filename}\" could not be found in #{@repository}/#{@arch}"
      redirect_to :controller => "package", :action => :binaries, :project => @project, 
        :package => @package, :repository => @repository, :nextstatus => 404
      return
    end
    @durl = "#{repo_url( @project, @repository )}/#{@fileinfo.arch}/#{@filename}" if @fileinfo.value :arch
    @durl = "#{repo_url( @project, @repository )}/iso/#{@filename}" if (@fileinfo.value :filename) =~ /\.iso$/
    if @durl and not file_available?( @durl )
      # ignore files not available
      @durl = nil
    end 
    if @user and !@durl
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
    @buildresult = find_cached(Buildresult, :project => @project, :package => @package,
      :repository => @repository, :view => ['binarylist', 'status'], :expires_in => 1.minute )
    unless @buildresult
      flash[:error] = "Package \"#{@package}\" has no build result for repository #{@repository}" 
      redirect_to :controller => "package", :action => :show, :project => @project, :package => @package, :nextstatus => 404  
      return
    end
    # load the flag details to disable links for forbidden binary downloads
    @package = find_cached(Package, @package.name, :project => @project, :view => :flagdetails )
  end

  def users
    fill_email_hash
  end

  def list_requests
  end

  def commit
    render :partial => 'commit_item', :locals => {:rev => params[:revision] }
  end

  def files
    @package.free_directory if discard_cache? || @revision != params[:rev] || @expand != params[:expand] || @srcmd5 != params[:srcmd5]
    @revision = params[:rev]
    @srcmd5   = params[:srcmd5]
    if params.has_key? :expand
      @expand = begin Integer(params[:expand]) rescue 1 end
    else
      @expand = 1
    end
    set_file_details
  end

  def service_parameter_value
    @values=Service.findAvailableParameterValues(params[:servicename], params[:parameter])
    render :partial => 'service_parameter_value_selector',
           :locals => { :servicename => params[:servicename], :parameter => params[:parameter], :number => params[:number], :value => params[:value], :setid => params[:setid] }
  end

  def source_history
    # hard coded value for the number of visible commit items in browser
    @visible_commits = 9
    @maxrevision = Package.current_rev(@project, @package.name).to_i
    @browserrevision = params[:rev]
    @browserrevision = @maxrevision if not @browserrevision

    # we need to fetch commits alltogether for the cache and not each single one
    if params[:showall]
      p = find_cached(Package, @package.name, :project => @project)
      p.cacheAllCommits
      @browserrevision = @visible_commits = @maxrevision
    end
  end

  def add_service
  end

  def create_submit_request_dialog
    @revision = Package.current_rev(@project, @package)
  end

  def create_submit_request
    req = BsRequest.new(:type => "submit", :targetproject => params[:target_project], :targetpackage => params[:target_package],
      :project => params[:project], :package => params[:package], :rev => params[:revision], :description => params[:description], :sourceupdate => params[:source_update])
    begin
      req.save(:create => true)
    rescue ActiveXML::Transport::NotFoundError => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
      redirect_to :action => :rdiff, :oproject => params[:targetproject], :opackage => params[:targetpackage],
        :project => params[:project], :package => params[:package]
      return
    end
    Rails.cache.delete "requests_new"
    redirect_to :controller => :request, :action => :show, :id => req.data["id"]
  end

  def service_parameter
    begin
      @serviceid = params[:serviceid]
      @servicename = params[:servicename]
      @services = find_cached(Service,  :project => @project, :package => @package )
      @parameters = @services.getParameters(@serviceid)
    rescue
      @parameters = []
    end
  end

  def update_parameters
    required_parameters :project, :package, :serviceid
    @project = params[:project]
    @package = params[:package]
    @serviceid = params[:serviceid]
    @services = find_cached(Service,  :project => @project, :package => @package )

    parameters=[]
    params.keys.each do |key|
      next unless key =~ /^parameter_/
      name = key.gsub(/^parameter_([^_]*)_/, '')
      parameters << { :name => name, :value => params[key] }
    end

    @services.setParameters( @serviceid, parameters )
    @services.save
    Service.free_cache :project => @project, :package => @package

    redirect_to :action => 'files', :project => @project, :package => @package
  end

  def set_file_details
    if not @revision and not @srcmd5
      # on very first page load only
      @revision = Package.current_rev(@project, @package)
      @current_revision = true
    else
      @current_revision = false
    end
    if @srcmd5
      @files = @package.files(@srcmd5, @expand)
    else
      @files = @package.files(@revision, @expand)
    end

    @spec_count = 0
    @files.each do |file|
      @spec_count += 1 if file[:ext] == "spec"
      if file[:name] == "_link"
        begin
          @link = find_cached(Link, :project => @project, :package => @package, :rev => @revision )
        rescue RuntimeError
          # possibly thrown on bad link files
        end
      elsif file[:name] == "_service" or file[:name] == "_service_error"
        begin
          @services = find_cached(Service,  :project => @project, :package => @package )
        rescue
          @services = nil
        end
        @serviceerror = @services.error if @services and @services.error
      end
    end
  end
  private :set_file_details

  def add_person
    @roles = Role.local_roles
    Package.free_cache :project => @project, :package => @package
  end

  def rdiff
    required_parameters :project, :package
    if params[:commit]
      @opackage = params[:package]
      @oproject = params[:project]
      @rev = params[:commit]
      @orev = (@rev.to_i - 1).to_s
    else
      required_parameters :opackage, :oproject
      @opackage = params[:opackage]
      @oproject = params[:oproject]
    end
    @rdiff = ''
    path = "/source/#{CGI.escape(params[:project])}/#{CGI.escape(params[:package])}?" +
      "opackage=#{CGI.escape(@opackage)}&oproject=#{CGI.escape(@oproject)}&unified=1&cmd=diff"
    path += "&linkrev=#{CGI.escape(params[:linkrev])}" if params[:linkrev]
    path += "&rev=#{CGI.escape(@rev)}" if @rev
    path += "&orev=#{CGI.escape(@orev)}" if @orev
    begin
      @rdiff = frontend.transport.direct_http URI(path + "&expand=1"), :method => "POST", :data => ""
    rescue ActiveXML::Transport::NotFoundError => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
      return
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:warn] = message
      begin
        @rdiff = frontend.transport.direct_http URI(path + "&expand=0"), :method => "POST", :data => ""
      rescue ActiveXML::Transport::Error => e
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
        flash[:error] = message
        return
      end
    end

    @lastreq = BsRequest.find_last_request(:targetproject => @oproject, :targetpackage => @opackage,
      :sourceproject => params[:project], :sourcepackage => params[:package])
    if @lastreq and @lastreq.state.name != "declined"
      @lastreq = nil # ignore all !declined
    end

  end

  def wizard_new
    if params[:name]
      if !valid_package_name_write? params[:name]
        flash[:error] = "Invalid package name: '#{params[:name]}'"
        redirect_to :action => 'wizard_new', :project => params[:project]
      else
        @package = Package.new( :name => params[:name], :project => @project )
        if @package.save
          redirect_to :action => 'wizard', :project => params[:project], :package => params[:name]
        else
          flash[:note] = "Failed to save package '#{@package}'"
          redirect_to :controller => 'project', :action => 'show', :project => params[:project]
        end
      end
    end
  end

  def wizard
    files = params[:wizard_files]
    fnames = {}
    if files
      logger.debug "files: #{files.inspect}"
      files.each_key do |key|
        file = files[key]
        next if ! file.respond_to?(:original_filename)
        fname = file.original_filename
        fnames[key] = fname
        # TODO: reuse code from PackageController#save_file and add_file.rhtml
        # to also support fetching remote urls
        @package.save_file :file => file, :filename => fname
      end
    end
    other = params[:wizard]
    if other
      response = other.merge(fnames)
    elsif ! fnames.empty?
      response = fnames
    else
      response = nil
    end
    @wizard = Wizard.find(:project => params[:project],
      :package => params[:package],
      :response => response)
  end


  def save_new
    valid_http_methods(:post)
    @package_name = params[:name]
    @package_title = params[:title]
    @package_description = params[:description]

    if !valid_package_name_write? params[:name]
      flash[:error] = "Invalid package name: '#{params[:name]}'"
      redirect_to :controller => :project, :action => 'new_package', :project => @project
      return
    end
    if package_exists? @project, @package_name
      flash[:error] = "Package '#{@package_name}' already exists in project '#{@project}'"
      redirect_to :controller => :project, :action => 'new_package', :project => @project
      return
    end

    @package = Package.new( :name => params[:name], :project => @project )
    @package.title.text = params[:title]
    @package.description.text = params[:description]
    if params[:source_protection]
      @package.add_element "sourceaccess"
      @package.sourceaccess.add_element "disable"
    end
    if params[:disable_publishing]
      @package.add_element "publish"
      @package.publish.add_element "disable"
    end
    if @package.save
      flash[:note] = "Package '#{@package}' was created successfully"
      Rails.cache.delete("%s_packages_mainpage" % @project)
      Rails.cache.delete("%s_problem_packages" % @project)
      Package.free_cache( :all, :project => @project.name )
      Package.free_cache( @package.name, :project => @project )
      redirect_to :action => 'show', :project => params[:project], :package => params[:name]
    else
      flash[:note] = "Failed to create package '#{@package}'"
      redirect_to :controller => 'project', :action => 'show', :project => params[:project]
    end
  end

  def branch
    valid_http_methods(:post)
    begin
      path = "/source/#{CGI.escape(params[:project])}/#{CGI.escape(params[:package])}?cmd=branch"
      result = XML::Document.string frontend.transport.direct_http( URI(path), :method => "POST", :data => "" )
      result_project = result.find_first( "/status/data[@name='targetproject']" ).content
      result_package = result.find_first( "/status/data[@name='targetpackage']" ).content
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
      redirect_to :controller => 'package', :action => 'show',
        :project => params[:project], :package => params[:package] and return
    end
    flash[:success] = "Branched package #{@project} / #{@package}"
    redirect_to :controller => 'package', :action => 'show',
      :project => result_project, :package => result_package and return
  end


  def save_new_link
    valid_http_methods(:post)
    @linked_project = params[:linked_project].strip
    @linked_package = params[:linked_package].strip
    @target_package = params[:target_package].strip
    @use_branch     = true if params[:branch]
    @revision       = nil
    @current_revision = true if params[:current_revision]

    if !valid_package_name_read? @linked_package
      flash[:error] = "Invalid package name: '#{@linked_package}'"
      redirect_to :controller => :project, :action => 'new_package_link', :project => params[:project] and return
    end

    if !valid_project_name? @linked_project
      flash[:error] = "Invalid project name: '#{@linked_project}'"
      redirect_to :controller => :project, :action => 'new_package_link', :project => params[:project] and return
    end

    linked_package = Package.find( @linked_package, :project => @linked_project )
    unless linked_package
      flash[:error] = "Unable to find package '#{@linked_package}' in" +
        " project '#{@linked_project}'."
      redirect_to :controller => :project, :action => "new_package_link", :project => @project and return
    end

    @target_package = @linked_package if @target_package.blank?
    if !valid_package_name_write? @target_package
      flash[:error] = "Invalid target package name: '#{@target_package}'"
      redirect_to :controller => :project, :action => "new_package_link", :project => @project and return
    end
    if package_exists? @project, @target_package
      flash[:error] = "Package '#{@target_package}' already exists in project '#{@project}'"
      redirect_to :controller => :project, :action => "new_package_link", :project => @project and return
    end

    if @current_revision
      @revision = Package.current_xsrcmd5(@linked_project, @linked_package)
      @revision = Package.current_rev(@linked_project, @linked_package) unless @revision
    end

    if @use_branch
      logger.debug "link params doing branch: #{@linked_project}, #{@linked_package}"
      begin
        path = "/source/#{CGI.escape(@linked_project)}/#{CGI.escape(@linked_package)}?cmd=branch&target_project=#{CGI.escape(@project.name)}&target_package=#{CGI.escape(@target_package)}"
        path += "&rev=#{CGI.escape(@revision)}" if @revision
        result = XML::Document.string frontend.transport.direct_http( URI(path), :method => "POST", :data => "" )
        flash[:success] = "Branched package #{@project.name} / #{@target_package}"
      rescue ActiveXML::Transport::Error => e
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
        flash[:error] = message
      end
    else
      # construct container for link
      package = Package.new( :name => @target_package, :project => @project )
      package.title.text = linked_package.title.text

      description = "This package is based on the package " +
        "'#{@linked_package}' from project '#{@linked_project}'.\n\n"

      description += linked_package.description.text if linked_package.description.text
      package.description.text = description
    
      begin
        saved = package.save
      rescue ActiveXML::Transport::ForbiddenError => e
        saved = false
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
        flash[:error] = message
        redirect_to :controller => 'project', :action => 'new_package_link',
          :project => @project and return
      end

      unless saved
        flash[:note] = "Failed to save package '#{package}'"
        redirect_to :controller => 'project', :action => 'new_package_link',
          :project => @project and return
        logger.debug "link params: #{@linked_project}, #{@linked_package}"
        link = Link.new( :project => @project,
          :package => @target_package, :linked_project => @linked_project, :linked_package => @linked_package )
        link.set_revision @revision if @revision
        link.save
        flash[:success] = "Successfully linked package '#{@linked_package}'"
      end
    end

    Rails.cache.delete("%s_packages_mainpage" % @project)
    Rails.cache.delete("%s_problem_packages" % @project)
    Package.free_cache( :all, :project => @project.name )
    Package.free_cache( @target_package, :project => @project )
    redirect_to :controller => 'package', :action => 'show', :project => @project, :package => @target_package
  end

  def save
    valid_http_methods(:post)
    @package.title.text = params[:title]
    @package.description.text = params[:description]
    if @package.save
      flash[:note] = "Package data for '#{@package.name}' was saved successfully"
    else
      flash[:note] = "Failed to save package '#{@package.name}'"
    end
    redirect_to :action => 'show', :project => params[:project], :package => params[:package]
  end

  def remove
    valid_http_methods(:post)
    begin
      FrontendCompat.new.delete_package :project => @project, :package => @package
      flash[:note] = "Package '#{@package}' was removed successfully from project '#{@project}'"
      Rails.cache.delete("%s_packages_mainpage" % @project)
      Rails.cache.delete("%s_problem_packages" % @project)
      Package.free_cache( :all, :project => @project.name )
      Package.free_cache( @package.name, :project => @project )
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
    end
    redirect_to :controller => 'project', :action => 'show', :project => @project
  end

  def add_file
    set_file_details
  end

  def save_file
    if request.method != :post
      flash[:warn] = "File upload failed because this was no POST request. " +
        "This probably happened because you were logged out in between. Please try again."
      redirect_to :action => :files, :project => @project, :package => @package and return
    end

    file = params[:file]
    file_url = params[:file_url]
    filename = params[:filename]

    if !file.blank?
      # we are getting an uploaded file
      filename = file.original_filename if filename.blank?

      if !valid_file_name?(filename)
        flash[:error] = "'#{filename}' is not a valid filename."
        redirect_to :action => 'add_file', :project => params[:project], :package => params[:package] and return
      end

      # extra escaping of filename (workaround for rails bug)
      @package.save_file :file => file, :filename => URI.escape(filename, "+")
    elsif not file_url.blank?
      # we have a remote file uri
      @services = find_cached(Service, :project => @project, :package => @package )
      unless @services
        @services = Service.new( :project => @project, :package => @package )
      end
      if @services.addDownloadURL( file_url )
         @services.save
         Service.free_cache :project => @project, :package => @package
      else
         flash[:error] = "Failed to add URL #{file_url} to service."
         redirect_to :action => 'add_file', :project => params[:project], :package => params[:package]
         return
      end
    else
      flash[:error] = 'No file or URI given.'
      redirect_to :action => 'add_file', :project => params[:project], :package => params[:package]
      return
    end

    if params[:addAsPatch]
      link = Link.find( :project => @project, :package => @package )
      if link
        link.add_patch filename
        link.save
      end
    elsif params[:applyAsPatch]
      link = Link.find( :project => @project, :package => @package )
      if link
        link.apply_patch filename
        link.save
      end
    end
    flash[:success] = "The file #{filename} has been added."
    @package.free_directory
    redirect_to :action => :files, :project => @project, :package => @package
  end

  def add_or_move_service
    id = params[:id]
    @services = find_cached(Service,  :project => @project, :package => @package )
    unless @services
      @services = Service.new(:project => @project, :package => @package)
    end

    if id =~ /^new_service_/
       id.gsub!( %r{^new_service_}, '' )
       @services.addService( id, params[:position].to_i )
       flash[:note] = "Service \##{id} added"
    elsif id =~ /^service_/
       id.gsub!( %r{^service_}, '' )
       @services.moveService( id.to_i, params[:position].to_i )
       flash[:note] = "Service \##{id} moved"
    else
       flash[:error] = "unkown object dropped"
    end

    @services.save
    Service.free_cache :project => @project, :package => @package
    redirect_to :action => :files, :project => @project, :package => @package and return
  end

  def execute_services
    @services = find_cached(Service,  :project => @project, :package => @package )
    @services.execute()
    flash[:note] = "Service execution got triggered"
    redirect_to :action => :files, :project => @project, :package => @package and return
  end

  def remove_service
    required_parameters :id
    id = params[:id].gsub( %r{^service_}, '' )
    @services = find_cached(Service,  :project => @project, :package => @package )
    @services.removeService( id )
    @services.save
    Service.free_cache :project => @project, :package => @package
    Directory.free_cache( :project => @project, :package => @package )
    flash[:note] = "Service \##{id} got removed"
    redirect_to :action => :files, :project => @project, :package => @package and return
  end

  def remove_file
    if request.method != :post
      flash[:warn] = "File removal failed because this was no POST request. " +
        "This probably happened because you were logged out in between. Please try again."
      redirect_to :action => :files, :project => @project, :package => @package and return
    end
    if not params[:filename]
      flash[:note] = "Removing file aborted: no filename given."
      redirect_to :action => :files, :project => @project, :package => @package
    end
    filename = params[:filename]
    # extra escaping of filename (workaround for rails bug)
    escaped_filename = URI.escape filename, "+"
    if @package.remove_file escaped_filename
      flash[:note] = "File '#{filename}' removed successfully"
      @package.free_directory
      # TODO: remove patches from _link
    else
      flash[:note] = "Failed to remove file '#{filename}'"
    end
    redirect_to :action => :files, :project => @project, :package => @package
  end

  def save_person
    valid_http_methods(:post)
    if not valid_role_name? params[:userid]
      flash[:error] = "Invalid username: #{params[:userid]}"
      redirect_to :action => :add_person, :project => @project, :package => @package, :role => params[:role]
      return
    end
    user = find_cached(Person, params[:userid] )
    unless user
      flash[:error] = "Unknown user '#{params[:userid]}'"
      redirect_to :action => :add_person, :project => @project, :package => params[:package], :role => params[:role]
      return
    end
    @package.add_person( :userid => params[:userid], :role => params[:role] )
    if @package.save
      flash[:note] = "Added user #{params[:userid]} with role #{params[:role]}"
    else
      flash[:note] = "Failed to add user '#{params[:userid]}'"
    end
    redirect_to :action => :users, :package => @package, :project => @project
  end


  def remove_person
    valid_http_methods(:post)
    @package.remove_persons( :userid => params[:userid], :role => params[:role] )
    if @package.save
      flash[:note] = "Removed user #{params[:userid]}"
    else
      flash[:note] = "Failed to remove user '#{params[:userid]}'"
    end
    redirect_to :action => :users, :package => @package, :project => @project
  end


  def edit_file
    @project = params[:project]
    @package = params[:package]
    @filename = params[:file]
    @comment = params[:comment]
    @expand = params[:expand]
    @srcmd5 = params[:srcmd5]
    @file = params[:content] || frontend.get_source( :project => @project,
      :package => @package, :filename => @filename, :rev => @srcmd5, :expand => @expand )
    # render explicitly as in error case this is called
    render :template => 'package/edit_file'
  end

  def view_file
    @filename = params[:file] || ''
    @expand = params[:expand]
    @srcmd5 = params[:srcmd5]
    @addeditlink = false
    if @package.can_edit?( session[:login] ) and !@srcmd5
      @package.files(@srcmd5, @expand).each do |file|
        if file[:name] == @filename
          @addeditlink = file[:editable]
          break
        end
      end
    end
    begin
      @file = frontend.get_source( :project => @project.to_s,
        :package => @package.to_s, :filename => @filename, :rev => @srcmd5 )
    rescue ActiveXML::Transport::NotFoundError => e
      flash[:error] = "File not found: #{@filename}"
      redirect_to :action => :files, :package => @package, :project => @project
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
      redirect_to :action => :files, :package => @package, :project => @project
    end
  end

  def save_modified_file
    project = params[:project]
    package = params[:package]
    if request.method != :post
      flash[:warn] = "Saving file failed because this was no POST request. " +
        "This probably happened because you were logged out in between. Please try again."
      redirect_to :action => :show, :project => project, :package => package and return
    end
    required_parameters :project, :package, :filename, :file
    filename = params[:filename]
    file = params[:file]
    comment = params[:comment]
    file.gsub!( /\r\n/, "\n" )
    begin
      frontend.put_file( file, :project => project, :package => package,
        :filename => filename, :comment => comment )
      flash[:note] = "Successfully saved file #{filename}"
      Directory.free_cache( :project => project, :package => package )
    rescue Timeout::Error => e
      flash[:error] = "Timeout when saving file. Please try again."
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      # if code == "validation_failed"
      flash[:error] = message
      params[:file] = filename
      params[:content] = file
      params[:comment] = comment
      edit_file # :package => package, :project => project, :file => filename, :content => file, :comment => comment
      return
    end
    redirect_to :action => :files, :package => package, :project => project
  end

  def rawlog
    valid_http_methods :get
    if CONFIG['use_lighttpd_x_rewrite']
      headers['X-Rewrite-URI'] = "/build/#{params[:project]}/#{params[:repository]}/#{params[:arch]}/#{params[:package]}/_log"
      headers['X-Rewrite-Host'] = FRONTEND_HOST
      head(200) and return
    end

    headers['Content-Type'] = 'text/plain'
    render :text => proc { |response, output|
      maxsize = 1024 * 256
      offset = 0
      while true
        begin
          chunk = frontend.get_log_chunk(params[:project], params[:package], params[:repository], params[:arch], offset, offset + maxsize )
        rescue ActiveXML::Transport::Error
          chunk = ''
        end
        if chunk.length == 0
          break
        end
        offset += chunk.length
        output.write(chunk)
      end
    }
  end

  def escape_log(log)
    log = CGI.escapeHTML(log)
    log.gsub(/[\t]/, '    ').gsub(/[\n\r]/n,"<br/>\n").gsub(' ', '&ensp;')
  end
  private :escape_log

  def live_build_log
    @arch = params[:arch]
    @repo = params[:repository]
    begin
      size = frontend.get_size_of_log(@project, @package, @repo, @arch)
      logger.debug("log size is %d" % size)
      @offset = size - 32 * 1024
      @offset = 0 if @offset < 0
      @initiallog = frontend.get_log_chunk( @project, @package, @repo, @arch, @offset, size)
    rescue => e
      logger.error "Got #{e.class}: #{e.message}; returning empty log."
      @initiallog = ''
    end
    @offset = (@offset || 0) + @initiallog.length
    @initiallog = escape_log(@initiallog)
    @initiallog.gsub!(/([^a-zA-Z0-9&;<>\/\n \t()])/n) do
      if $1[0].to_i < 32
        ''
      else
        $1
      end
    end
  end


  def update_build_log
    @project = params[:project]
    @package = params[:package]
    @arch = params[:arch]
    @repo = params[:repository]
    @initial = params[:initial]
    @offset = params[:offset].to_i
    @finished = false
    maxsize = 1024 * 64

    begin
      log_chunk = frontend.get_log_chunk( @project, @package, @repo, @arch, @offset, @offset + maxsize)

      if( log_chunk.length == 0 )
        @finished = true
      else
        @offset += log_chunk.length
        log_chunk = escape_log(log_chunk)
      end

    rescue Timeout::Error => ex
      log_chunk = ""

    rescue => e
      log_chunk = "No live log available"
      @finished = true
    end

    render :update do |page|

      logger.debug 'finished ' + @finished.to_s

      if @finished
        page.call 'build_finished'
        page.call 'hide_abort'
      else
        page.call 'show_abort'
        page.insert_html :bottom, 'log_space', log_chunk
        if log_chunk.length < maxsize || @initial == 0
          page.call 'autoscroll'
          page.delay(2) do
            page.call 'refresh', @offset, 0
          end
        else
          logger.debug 'call refresh without delay'
          page.call 'refresh', @offset, @initial
        end
      end
    end
  end

  def abort_build
    params[:redirect] = 'live_build_log'
    api_cmd('abortbuild', params)
  end


  def trigger_rebuild
    valid_http_methods :delete
    api_cmd('rebuild', params)
  end

  def wipe_binaries
    valid_http_methods :delete
    api_cmd('wipe', params)
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
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
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
      flash[:note] = @message
      redirect_to :controller => controller, :action => action,
        :project => @project, :package => @package
    else
      # ajax request - render default view: in this case 'trigger_rebuild.rjs'
      return
    end
  end
  private :api_cmd
  
  def import_spec
    all_files = @package.files
    all_files.each do |file|
      @specfile_name = file[:name] if file[:name].grep(/\.spec/) != []
    end
    specfile_content = frontend.get_source(
      :project => params[:project], :package => params[:package], :filename => @specfile_name
    )

    description = []
    lines = specfile_content.split(/\n/)
    line = lines.shift until line =~ /^%description\s*$/
    description << lines.shift until description.last =~ /^%/
    # maybe the above end-detection of the description-section could be improved like this:
    # description << lines.shift until description.last =~ /^%\{?(debug_package|prep|pre|preun|....)/
    description.pop

    render :text => description.join("\n")
    logger.debug "imported description from spec file"
  end

  def reload_buildstatus
    # discard cache
    Buildresult.free_cache( :project => @project, :package => @package, :view => 'status' )
    @buildresult = find_cached(Buildresult, :project => @project, :package => @package, :view => 'status', :expires_in => 5.minutes )
    fill_status_cache unless @buildresult.blank?
    render :partial => 'buildstatus'
  end


  def set_url_form
    if @package.has_element? :url
      @new_url = @package.url.to_s
    else
      @new_url = 'http://'
    end
    render :partial => "set_url_form"
  end

  def edit_meta
    render :template => "package/edit_meta"
  end

  def meta
  end

  def save_meta
    begin
      frontend.put_file(params[:meta], :project => @project, :package => @package, :filename => '_meta')
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
      @meta = params[:meta]
      edit_meta
      return
    end
    
    flash[:note] = "Config successfully saved"
    Package.free_cache @package, :project => @project
    redirect_to :action => :meta, :project => @project, :package => @package
  end

  def attributes
    @attributes = find_cached(Attribute, {:project => @project.name, :package => @package.to_s}, :expires_in => 2.minutes)
  end

  def edit
  end

  def set_url
    @package.set_url params[:url]
    render :partial => 'url_line', :locals => { :url => params[:url] }
  end

  def remove_url
    @package.remove_url
    redirect_to :action => "show", :project => params[:project], :package => params[:package]
  end

  def repositories
    @package = find_cached(Package, params[:package], :project => params[:project], :view => :flagdetails )
  end

  def change_flag
    if request.post? and params[:cmd] and params[:flag]
      frontend.source_cmd params[:cmd], :project => @project, :package => @package, :repository => params[:repository], :arch => params[:arch], :flag => params[:flag], :status => params[:status]
    end
    Package.free_cache( params[:package], :project => @project.name, :view => :flagdetails )
    if request.xhr?
      @package = find_cached(Package, params[:package], :project => @project.name, :view => :flagdetails )
      render :partial => 'shared/repositories_flag_table', :locals => { :flags => @package.send(params[:flag]), :obj => @package }
    else
      redirect_to :action => :repositories, :project => @project, :package => @package
    end
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

  def require_project
    unless params[:project].blank?
      @project = find_cached(Project, params[:project], :expires_in => 5.minutes )
    end
    unless @project
      logger.error "Project #{params[:project]} not found"
      flash[:error] = "Project not found: \"#{params[:project]}\""
      redirect_to :controller => "project", :action => "list_public" and return
    end
  end

  def require_package
    unless valid_package_name_read? params[:package]
      logger.error "Package #{@project}/#{params[:package]} not valid"
      flash[:error] = "\"#{params[:package]}\" is not a valid package name"
      redirect_to :controller => "project", :action => :packages, :project => @project, :nextstatus => 404
      return
    end
    @project ||= params[:project]
    unless params[:package].blank?
      @package = find_cached(Package, params[:package], :project => @project )
    end
    unless @package
      logger.error "Package #{@project}/#{params[:package]} not found"
      flash[:error] = "Package \"#{params[:package]}\" not found in project \"#{params[:project]}\""
      redirect_to :controller => "project", :action => :packages, :project => @project, :nextstatus => 404
    end
  end

  def require_meta
    begin
      @meta = frontend.get_source(:project => params[:project], :package => params[:package], :filename => '_meta')
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "Package _meta not found: #{params[:project]}/#{params[:package]}"
      redirect_to :controller => "project", :action => "show", :project => params[:project], :nextstatus => 404
    end
  end

  def fill_status_cache
    @repohash = Hash.new
    @statushash = Hash.new
    @packagenames = Array.new
    @repostatushash = Hash.new
    @failures = 0

    @buildresult.each_result do |result|
      @resultvalue = result
      repo = result.repository
      arch = result.arch

      @repohash[repo] ||= Array.new
      @repohash[repo] << arch

      # package status cache
      @statushash[repo] ||= Hash.new
      @statushash[repo][arch] = Hash.new

      stathash = @statushash[repo][arch]
      result.each_status do |status|
        stathash[status.package] = status
        if ['unresolvable', 'failed', 'broken'].include? status.code
          @failures += 1
        end
      end

      # repository status cache
      @repostatushash[repo] ||= Hash.new
      @repostatushash[repo][arch] = Hash.new

      if result.has_attribute? :state
        if result.has_attribute? :dirty
          @repostatushash[repo][arch] = "outdated_" + result.state.to_s
        else
          @repostatushash[repo][arch] = result.state.to_s
        end
      end

      @packagenames << stathash.keys
    end

    if @buildresult and !@buildresult.has_element? :result
      @buildresult = nil
    end

    return unless @buildresult

    newr = Hash.new
    @buildresult.each_result.sort {|a,b| a.repository <=> b.repository}.each do |result|
      repo = result.repository
      if result.has_element? :status
        newr[repo] ||= Array.new
        newr[repo] << result.arch
      end
    end

    @buildresult = Array.new
    newr.keys.sort.each do |r|
      @buildresult << [r, newr[r].flatten.sort]
    end
  end

  def load_current_requests
    predicate = "state/@name='new' and action/target/@project='#{@project}' and action/target/@package='#{@package}'"
    @current_requests = Array.new
    coll = find_cached(Collection, :what => :request, :predicate => predicate, :expires_in => 1.minutes)
    coll.each_request do |req|
      @current_requests << req
    end
    @package_has_requests = !@current_requests.blank?
  end

end
