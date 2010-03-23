require 'open-uri'
require 'project'

class PackageController < ApplicationController

  before_filter :require_project, :only => [:new, :new_link, :wizard_new, :show, :wizard, 
    :edit, :add_file, :save_file, :save_new, :save_new_link, :flags_for_experts, :reload_buildstatus,
    :update_flag, :remove, :view_file, :live_build_log, :rdiff, :users, :files, :attributes]
  before_filter :require_package, :only => [:save, :remove_file, :add_person, :save_person, 
    :remove_person, :set_url, :remove_url, :set_url_form, :flags_for_experts, :reload_buildstatus,
    :show, :wizard, :edit, :add_file, :save_file, :reload_buildstatus, :update_flag, :view_file, 
    :remove, :live_build_log, :rdiff, :users, :files, :attributes]
  before_filter :check_user, :only => [:users]

  def fill_email_hash
    @email_hash = Hash.new
    persons = [@package.each_person, @project.each_person].flatten.map{|p| p.userid.to_s}.uniq
    persons.each do |person|
      @email_hash[person] = Person.find_cached(person).email.to_s
    end
    @roles = Role.local_roles
  end

  def show
    @buildresult = Buildresult.find_cached( :project => @project, :package => @package, :view => ['status', 'binarylist'], :expires_in => 5.minutes )
    if @package.bugowner
      @bugowner_mail = Person.find_cached( @package.bugowner ).email.to_s
    elsif @project.bugowner
      @bugowner_mail = Person.find_cached( @project.bugowner ).email.to_s
    end

    fill_status_cache
  end
  
  def users
    fill_email_hash
  end

  def files
    @files = get_files @project, @package
    @spec_count = 0
    @files.each do |file|
      @spec_count += 1 if file[:ext] == "spec"
      if file[:name] == "_link"
        @link = Link.find( :project => @project, :package => @package )
      end
      if file[:name] == "_service"
        @service = Service.find( :project => @project, :package => @package )
      end
    end
  end

  def add_person
    @roles = Role.local_roles
  end

  def rdiff
    @opackage = params[:opackage]
    @oproject = params[:oproject]
    path = "/source/#{CGI.escape(params[:project])}/#{CGI.escape(params[:package])}?" +
           "opackage=#{CGI.escape(params[:opackage])}&oproject=#{CGI.escape(params[:oproject])}&expand=1&unified=1&cmd=diff"
    begin
      @rdiff = frontend.transport.direct_http URI(path), :method => "POST", :data => ""
    rescue ActiveXML::Transport::NotFoundError => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
      @rdiff = ''
      return
    end

    @lastreq = Request.find_last_request(:targetproject => params[:oproject], :targetpackage => params[:opackage],
	                                 :sourceproject => params[:project], :sourcepackage => params[:package])
    if @lastreq and @lastreq.state.name != "declined"
      @lastreq = nil # ignore all !declined
    end
   
  end

  def create_submit
    rev = Package.current_rev(params[:project], params[:package])
    req = Request.new(:type => "submit", :targetproject => params[:targetproject], :targetpackage => params[:targetpackage],
		      :project => params[:project], :package => params[:package], :rev => rev, :description => params[:description])
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
    redirect_to :controller => :request, :action => :diff, :id => req.data["id"]
  end

  def wizard_new
    if params[:name]
      if !valid_package_name? params[:name]
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
    @package_name = params[:name]
    @package_title = params[:title]
    @package_description = params[:description]

    if !valid_package_name? params[:name]
      flash.now[:error] = "Invalid package name: '#{params[:name]}'"
      render :action => 'new' and return
    end
    if Package.exists? @package_name, @project
      flash.now[:error] = "Package '#{@package_name}' already exists in project '#{@project}'"
      render :action => 'new' and return
    end

    @package = Package.new( :name => params[:name], :project => @project )
    @package.title.text = params[:title]
    @package.description.text = params[:description]
    if @package.save
      flash[:note] = "Package '#{@package}' was created successfully"
      redirect_to :action => 'show', :project => params[:project], :package => params[:name]
    else
      flash[:note] = "Failed to create package '#{@package}'"
      redirect_to :controller => 'project', :action => 'show', :project => params[:project]
    end
  end

  
  def save_new_link
    @linked_project = params[:linked_project].strip
    @linked_package = params[:linked_package].strip
    @target_package = params[:target_package].strip

    linked_package = Package.find_cached( @linked_package, :project => @linked_project )
    unless linked_package
      flash.now[:error] = "Unable to find package '#{@linked_package}' in" +
        " project '#{@linked_project}'."
      render :action => "new_link" and return
    end

    @target_package = @linked_package if @target_package.blank?
    if !valid_package_name? @target_package
      flash.now[:error] = "Invalid target package name: '#{@target_package}'"
      render :action => "new_link" and return
    end
    if Package.exists? @target_package, @project
      flash.now[:error] = "Package '#{@target_package}' already exists in project '#{@project}'"
      render :action => 'new_link' and return
    end
      
    package = Package.new( :name => @target_package, :project => params[:project] )
    package.title.text = linked_package.title.text

    description = "This package is based on the package " +
      "'#{@linked_package}' from project '#{@linked_project}'.\n\n"

    description += linked_package.description.text if linked_package.description.text
    package.description.text = description

    unless package.save
      flash[:note] = "Failed to save package '#{package}'"
      redirect_to :controller => 'project', :action => 'show',
        :project => params[:project] and return
    else
      logger.debug "link params: #{@linked_project}, #{@linked_package}"
      link = Link.new( :project => params[:project],
        :package => @target_package, :linked_project => @linked_project, :linked_package => @linked_package )
      link.save
      flash[:note] = "Successfully linked package '#{@linked_package}'"
      redirect_to :controller => 'project', :action => 'show', :project => params[:project]
    end
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
    rescue Object => e
      flash[:error] = "Failed to remove package '#{@package}' from project '#{@project}': #{e.message}"
    end
    redirect_to :controller => 'project', :action => 'show', :project => @project
  end

  def add_file
    if Link.find( :project => @project.name, :package => @package.name )
      @package_is_link = true
    else
      @package_is_link = false
    end
  end

  def save_file
    if request.method != :post
      flash[:warn] = "File upload failed because this was no POST request. " +
        "This probably happened because you were logged out in between. Please try again."
      redirect_to :action => :show, :project => @project, :package => @package and return
    end

    file = params[:file]
    file_url = params[:file_url]
    filename = params[:filename]

    if !file.blank?
      # we are getting an uploaded file
      filename = file.original_filename if filename.blank?
    elsif not file_url.blank?
      # we have a remote file uri
      begin
        start = Time.now
        uri = URI::parse file_url
        filename = uri.path.match('.*\/([^\/\?]+)')[1] if filename.blank?
        logger.info "Adding file: #{filename} from url: #{file_url}"
        if filename.blank? or filename == '/'
          flash[:error] = 'Invalid filename: #{filename}, please choose another one.'
          redirect_to :action => 'add_file', :project => params[:project], :package => params[:package]
          return
        end 
        file = open uri
      rescue Object => e
        flash[:error] = "Error retrieving URI '#{uri}': #{e.message}."
        logger.error "Error downloading file: #{e.message}"
        redirect_to :action => 'add_file', :project => params[:project], :package => params[:package]
        return
      ensure
        logger.debug "Download from #{file_url} took #{Time.now - start} seconds"
      end
    else
      flash[:error] = 'No file or URI given.'
      redirect_to :action => 'add_file', :project => params[:project], :package => params[:package]
      return
    end

    if !valid_file_name?(filename)
      flash[:error] = "'#{filename}' is not a valid filename."
      redirect_to :action => 'add_file', :project => params[:project], :package => params[:package] and return
    end

    # extra escaping of filename (workaround for rails bug)
    @package.save_file :file => file, :filename => URI.escape(filename, "+")

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
    redirect_to :action => :show, :project => @project, :package => @package
  end

  def remove_file
    if request.method != :post
      flash[:warn] = "File removal failed because this was no POST request. " +
        "This probably happened because you were logged out in between. Please try again."
      redirect_to :action => :show, :project => @project, :package => @package and return
    end
    if not params[:filename]
      flash[:note] = "Removing file aborted: no filename given."
      redirect_to :action => :show, :project => @project, :package => @package
    end
    filename = params[:filename]
    # extra escaping of filename (workaround for rails bug)
    escaped_filename = URI.escape filename, "+"
    if @package.remove_file escaped_filename
      flash[:note] = "File '#{filename}' removed successfully"
      # TODO: remove patches from _link
    else
      flash[:note] = "Failed to remove file '#{filename}'"
    end
    redirect_to :action => :show, :project => @project, :package => @package
  end

  def save_person
    valid_http_methods(:post)
    if not valid_role_name? params[:userid]
      flash[:error] = "Invalid username: #{params[:userid]}"
      redirect_to :action => :add_person, :project => @project, :package => @package, :role => params[:role]
      return
    end
    user = Person.find_cached( :login => params[:userid] )
    unless user
      flash[:error] = "Unknown user '#{params[:userid]}'"
      redirect_to :action => :add_person, :project => @project, :package => params[:package], :role => params[:role]
      return
    end
    logger.debug "found user: #{user.inspect}"
    @package.add_person( :userid => params[:userid], :role => params[:role] )
    if @package.save
      flash[:note] = "added user #{params[:userid]}"
    else
      flash[:note] = "Failed to add user '#{params[:userid]}'"
    end
    redirect_to :action => :show, :package => @package, :project => @project
  end


  def remove_person
    valid_http_methods(:post)
    @package.remove_persons( :userid => params[:userid], :role => params[:role] )
    if @package.save
      flash[:note] = "removed user #{params[:userid]}"
    else
      flash[:note] = "Failed to remove user '#{params[:userid]}'"
    end
    redirect_to :action => :show, :package => params[:package], :project => params[:project]
  end


  def edit_file
    @project = params[:project]
    @package = params[:package]
    @filename = params[:file]
    @file = frontend.get_source( :project => @project,
      :package => @package, :filename => @filename )
  end

  def view_file
    @filename = params[:file] || ''
    @addeditlink = false
    if @project.is_maintainer?( session[:login] ) || @package.is_maintainer?( session[:login] )
      get_files( @project.name, @package.name ).each do |file|
        if file[:name] == @filename
          @addeditlink = file[:editable]
          break
        end
      end
    end
    begin
      @file = frontend.get_source( :project => @project,
        :package => @package, :filename => @filename )
    rescue ActiveXML::Transport::NotFoundError => e
      flash[:error] = "File not found: #{@filename}"
      redirect_to :action => :show, :package => @package, :project => @project
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
    required_parameters(params, [:project, :package, :filename, :file])
    filename = params[:filename]
    file = params[:file]
    comment = params[:comment]
    file.gsub!( /\r\n/, "\n" )
    begin
      frontend.put_file( file, :project => project, :package => package,
        :filename => filename, :comment => comment )
      flash[:note] = "Successfully saved file #{filename}"
    rescue Timeout::Error => e
      flash[:error] = "Timeout when saving file. Please try again."
    end
    redirect_to :action => :show, :package => package, :project => project
  end

  def rawlog
    valid_http_methods :get
    headers['Content-Type'] = 'text/plain'
    render :text => proc { |response, output| 
      maxsize = 1024 * 256
      offset = 0
      while true
        chunk = frontend.get_log_chunk(params[:project], params[:package], params[:repository], params[:arch], offset, offset + maxsize )
        if chunk.length == 0
          break
        end
        offset += chunk.length
        output.write(chunk)
        output.flush
      end
    }
  end

  def live_build_log
    @arch = params[:arch]
    @repo = params[:repository]
    begin
      size = frontend.get_size_of_log(@project, @package, @repo, @arch)
      logger.debug("log size is %d" % size)
      @offset = size - 32 * 1024
      @offset = 0 if @offset < 0
      maxsize = 1024 * 64
      @initiallog = frontend.get_log_chunk( @project, @package, @repo, @arch, @offset, @offset + maxsize)
    rescue => e
      logger.error "Got #{e.class}: #{e.message}; returning empty log."
      @initiallog = ''
    end
    @offset = (@offset || 0) + @initiallog.length
    @initiallog = CGI.escapeHTML(@initiallog);
    @initiallog = @initiallog.gsub("\n","<br/>").gsub(" ","&nbsp;")
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
        log_chunk = CGI.escapeHTML(log_chunk);
        log_chunk = log_chunk.gsub("\n","<br/>").gsub(" ","&nbsp;")
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
        page.hide 'link_abort_build'
        page.show 'link_trigger_rebuild'
      else
        page.show 'link_abort_build'
        page.hide 'link_trigger_rebuild'
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
    render :status => 200
  end


  def trigger_rebuild
    api_cmd('rebuild', params)
  end

  def api_cmd(cmd, params)
    project = params[:project]
    unless project
      flash[:error] = "Project name missing."
      redirect_to :controller => "project", :action => 'list_public'
      return
    end

    package = params[:package]
    unless package
      flash[:error] = "Package name missing."
      redirect_to :controller => "project", :action => 'show',
        :project => project
      return
    end

    options = {}
    options[:arch] = params[:arch] if params[:arch]
    options[:repository] = params[:repo] if params[:repo]
    options[:project] = project
    options[:package] = package

    begin
      frontend.cmd cmd, options
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "No repository defined"
      redirect_to :controller => "project", :action => :add_target_simple, :project => project
      return
    end

    logger.debug( "Triggered Rebuild for #{package}, options=#{options.inspect}" )

    if  params[:redirect] == 'monitor'
      controller = 'project'
      action = 'monitor'
      @message = "Triggered #{cmd} for package #{package}."
    elsif params[:redirect] == 'live_build_log'
      # assume xhr
      return
    else
      controller = 'package'
      action = 'show'
      @message = "Triggered #{cmd}."
    end

    unless request.xhr?
      # non ajax request:
      flash[:note] = @message
      redirect_to :controller => controller, :action => action,
        :project => project, :package => package
    else
      # ajax request - render default view: in this case 'trigger_rebuild.rjs'
    end
  end

  def render_nothing
    render :nothing => true
  end


  def disable_build
    return false unless @package = Package.find_cached( params[:package], :project => params[:project] )

    # disable building of a package
    if params[:arch] && params[:repo]
      if @package.disable_build :repo => params[:repo], :arch => params[:arch]
        flash[:note] = "Disabled building of package '#{params[:package]}' in project '#{params[:project]}' for repo '#{params[:repo]}' / arch '#{params[:arch]}'."
      else
        flash[:error] = "Insufficient permissions"
      end
    else
      if params[:repo]
        if @package.disable_build :repo => params[:repo]
          flash[:note] = "Disabled building of package '#{params[:package]}' in project '#{params[:project]}' for repo '#{params[:repo]}'."
        else
          flash[:error] = "Insufficient permissions"
        end
      elsif params[:arch]
        if @package.disable_build :arch => params[:arch]
          flash[:note] = "Disabled building of package '#{params[:package]}' in project '#{params[:project]}' for arch '#{params[:arch]}'."
        else
          flash[:error] = "Insufficient permissions"
        end
      else
        if @package.disable_build
          flash[:note] = "Disabled building of package '#{params[:package]}' in project '#{params[:project]}' completely."
        else
          flash[:error] = "Insufficient permissions"
        end
      end
    end
    redirect_to :action => "show", :project => params[:project], :package => params[:package]
  end


  def enable_build
    return false unless @package = Package.find_cached( params[:package], :project => params[:project] )

    # (re)-enable building of a package
    if params[:arch] && params[:repo]
      if @package.enable_build :repo => params[:repo], :arch => params[:arch]
        flash[:note] = "Enabled building of package '#{params[:package]}' in project '#{params[:project]}' for repo '#{params[:repo]}' / arch '#{params[:arch]}'."
      else
        flash[:error] = "Insufficient permissions"
      end
    else
      if params[:repo]
        if @package.enable_build :repo => params[:repo]
          flash[:note] = "Enabled building of package '#{params[:package]}' in project '#{params[:project]}' for repo '#{params[:repo]}'."
        else
          flash[:error] = "Insufficient permissions"
        end
      elsif params[:arch]
        if @package.enable_build :arch => params[:arch]
          flash[:note] = "Enabled building of package '#{params[:package]}' in project '#{params[:project]}' for arch '#{params[:arch]}'."
        else
          flash[:error] = "Insufficient permissions"
        end
      else
        if @package.enable_build
          flash[:note] = "Enabled building of package '#{params[:package]}' in project '#{params[:project]}'."
        else
          flash[:error] = "Insufficient permissions"
        end
      end
    end
    redirect_to :action => "show", :project => params[:project], :package => params[:package]
  end


  def import_spec
    return false unless @package = Package.find_cached( params[:package], :project => params[:project] )

    all_files = get_files params[:project], params[:package]
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


  def edit_disable_xml
    return false unless @package = Package.find_cached( params[:package], :project => params[:project] )
    return false unless @project = Project.find_cached( params[:project] )
    @xml = @package.get_disable_tags
    render :partial => 'edit_disable_xml'
  end


  def save_disable_xml
    return false unless @package = Package.find_cached( params[:package], :project => params[:project] )
    unless @package.replace_disable_tags( params[:xml] )
      flash[:error] = 'Error saving your input (invalid XML?).'
    end
    redirect_to :action => 'show', :project => params[:project], :package => params[:package]
  end


  def reload_buildstatus
    # discard cache
    Buildresult.free_cache( :project => @project, :package => @package, :view => ['status', 'binarylist'] )
    @buildresult = Buildresult.find_cached( :project => @project, :package => @package, :view => ['status', 'binarylist'] )
    fill_status_cache
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


  def set_url
    @package.set_url params[:url]
    render :partial => 'url_line', :locals => { :url => params[:url] }
  end


  def remove_url
    @package.remove_url
    redirect_to :action => "show", :project => params[:project], :package => params[:package]
  end


  # update package flags
  def update_flag
    begin
      #the flag matrix will also be initialized on access, so we can work on it
      if @package.complex_flag_configuration? params[:flag_name]
        raise RuntimeError.new("Your flag configuration seems to be too complex to be saved through this interface. Please use OSC.")
      end
      @package.replace_flags(params)
    rescue RuntimeError => exception
      @error = exception
      logger.debug "[PACKAGE:] Flag-Update-Error: flag configuration is rejected to be saved because of its complexity."
    rescue  ActiveXML::Transport::Error => exception
      @error = exception
      logger.debug "[PACKAGE:] Flag-Update-Error: #{@error}"
    end
    @flag = @package.send("#{params[:flag_name]}"+"flags")[params[:flag_id].to_sym]
  end


  def flags_for_experts
    render :template => "flag/package_flags_for_experts"
  end


  private

  def get_files( project, package )
    # files whose name ends in the following extensions should not be editable
    no_edit_ext = %w{ .bz2 .dll .exe .gem .gif .gz .jar .jpeg .jpg .lzma .ogg .pdf .pk3 .png .ps .rpm .svgz .tar .taz .tb2 .tbz .tbz2 .tgz .tlz .txz .xpm .xz .z .zip }
    files = []
    dir = Directory.find( :project => project, :package => package )
    return files unless dir
    dir.each_entry do |entry|
      file = Hash[*[:name, :size, :mtime, :md5].map {|x| [x, entry.send(x.to_s)]}.flatten]
      file[:ext] = Pathname.new(file[:name]).extname
      file[:editable] = ((not no_edit_ext.include?( file[:ext].downcase )) and file[:size].to_i < 2**20)  # max. 1 MB
      files << file
    end
  # TODO: <linkinfo project="openSUSE:Factory" package="bash" srcmd5="071e073dfd086d97db708deed661a274" baserev="ecb392833f88d01c094404117886b103" xsrcmd5="29d1bfad47af58e8f0033bc02080c2d6" lsrcmd5="b504c8b0bdd073474ce0dc1d7d7b4767" />
    return files
  end

  def require_project
    if params[:project]
      @project = Project.find_cached( params[:project] )
    end
    unless @project
      logger.error "Project #{params[:project]} not found"
      flash[:error] = "Project not found: \"#{params[:project]}\""
      redirect_to :controller => "project", :action => "list_public" and return
    end
  end

  def require_package
    @project ||= params[:project]
    if params[:package]
      @package = Package.find_cached( params[:package], :project => @project )
    end
    unless @package
      logger.error "Package #{@project}/#{params[:package]} not found"
      flash[:error] = "Package \"#{params[:package]}\" not found in project \"#{params[:project]}\""
      redirect_to :controller => "project", :action => :show, :project => @project and return
    end
  end

  def fill_status_cache
    @repohash = Hash.new
    @statushash = Hash.new
    @repostatushash = Hash.new
    @packagenames = Array.new

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
      end

     @packagenames << stathash.keys

     # repository status cache
     @repostatushash[repo] ||= Hash.new
     @repostatushash[repo][arch] = Hash.new

      if result.has_attribute? :state
        if result.has_attribute? :dirty
          @repostatushash[repo][arch] = "outdated(#{result.state})"
        else
          @repostatushash[repo][arch] = "#{result.state}"
        end
      end
    end
    
  end

end


