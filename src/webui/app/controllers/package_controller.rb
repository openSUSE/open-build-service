require 'open-uri'

class PackageController < ApplicationController

  before_filter :check_params
  before_filter :require_project, :only => [:new, :new_link, :wizard_new, :show, :view, :wizard, 
    :edit, :add_file, :save_file, :save_new, :save_new_link]
  before_filter :require_package, :only => [:save, :remove_file, :add_person, :save_person, 
    :remove_person, :set_url, :remove_url, :set_url_form, :flags_for_experts, :reload_buildstatus,
    :show, :view, :wizard, :edit, :add_file, :save_file]

  def index
    redirect_to :controller => 'project', :action => 'list_all'
  end

    # render the input form for tags
  def add_tag_form
    @project = params[:project]
    @package = params[:package]
    render :partial => "add_tag_form"
  end


  def add_tag
    logger.debug "New tag #{params[:tag]} for package #{params[:package]}."

    tags = []
    tags << params[:tag]
    old_tags = Tag.find(:user => session[:login], :project => params[:project], :package => params[:package])

    old_tags.each_tag do |tag|
      tags << tag.name
    end
    logger.debug "[TAG:] saving tags #{tags.join(" ")} for package #{params[:package]} (project #{params[:project]})."

    @tag_xml = Tag.new(:user => session[:login], :project => params[:project], :package => params[:package], :tag => tags.join(" "))
    begin
      @tag_xml.save()
    rescue ActiveXML::Transport::Error => exception
      rescue_action_in_public exception
      @error = CGI::escapeHTML(@message)
      logger.debug "[TAG:] Error: #{@message}"
      @unsaved_tags = true
    end

    @tags, @user_tags_array = get_tags(:user => session[:login], :project => params[:project], :package => params[:package])

    render :update do |page|
      page.replace_html 'tag_area', :partial => "tags_ajax"
      page.visual_effect :highlight, 'tag_area'
       if @unsaved_tags
        page.replace_html 'error_message', "WARNING: #{@error}"
        page.show 'error_message'
        page.delay(30) do
          page.hide 'error_message'
        end
      end
    end
  end


  def show_packages_by_tag
    @collection = Collection.find(:tag, :type => "_packages", :tagname => params[:tag])
    @packages = []
    @collection.each_package do |package|
      @packages << package
    end
    render :action => "../tag/list_objects_by_tag"
  end

  def show
    @files = get_files @project, @package
    @spec_count = 0
    @files.each do |file|
      @spec_count += 1 if file[:ext] == "spec"
      if ( file[:name] == "_link" )
        begin
          @link = Link.find( :project => @project, :package => @package )
        rescue ActiveXML::Transport::NotFoundError, REXML::ParseException
          @link = nil
        end
      end
    end

    @email_hash = Hash.new
    persons = [@package.each_person, @project.each_person].flatten.map{|p| p.userid.to_s}.uniq
    persons.each do |person|
      @email_hash[person] = Person.find_cached(person).email.to_s
    end
    @buildresult = Buildresult.find( :project => @project, :package => @package, :view => ['status', 'binarylist'] )
    @tags, @user_tags_array = get_tags(:project => @project, :package => @package, :user => session[:login])
    @rating = Rating.find( :project => @project, :package => @package )
  end

  
  def get_tags(params)
   tags = Tag.find(:tags_by_object, :project => params[:project], :package => params[:package])
   user_tags = Tag.find(:project => params[:project], :package => params[:package], :user => params[:user])
   user_tags_array = []
   user_tags.each_tag do |tag|
    user_tags_array << tag.name
   end
   return tags, user_tags_array
  end

  # @deprecated
  def view
    #@tags = Tag.find(:user => session[:login], :project => @project.name, :package => @package.name)
    #TODO not efficient, @user_tags_array is needed because of shared _tags_ajax.rhtml
    @tags, @user_tags_array = get_tags(:project => params[:project], :package => params[:package], :user => session[:login])

    @downloads = Downloadcounter.find( :project => project, :package => package )
    @rating = Rating.find( :project => @project, :package => @package )
    @created_timestamp = LatestAdded.find( :specific,
      :project => @project, :package => @package ).package.created
    @updated_timestamp = LatestUpdated.find( :specific,
      :project => @project, :package => @package ).package.updated
    @activity = ( MostActive.find( :specific, :project => @project,
      :package => @package).package.activity.to_f * 100 ).round.to_f / 100
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
    if params[:name]
      if !valid_package_name? params[:name]
        flash.now[:error] = "Invalid package name: '#{params[:name]}'"
        @package_name = params[:name]
        @package_title = params[:title]
        @package_description = params[:description]
        render :action => 'new'
      else
        @package = Package.new( :name => params[:name], :project => @project )
        @package.title.data.text = params[:title]
        @package.description.data.text = params[:description]

        if @package.save
          flash[:note] = "Package '#{@package}' was created successfully"
          redirect_to :action => 'show', :project => params[:project], :package => params[:name]
        else
          flash[:note] = "Failed to create package '#{@package}'"
          redirect_to :controller => 'project', :action => 'show', :project => params[:project]
        end
      end
    end
  end

  def save_new_link
    params[:linked_package].strip!
    params[:linked_project].strip!
    params[:target_package].strip!
    begin
      linked_package = Package.find( params[:linked_package],
        :project => params[:linked_project] )
    rescue: ActiveXML::NotFoundError
      @linked_project = params[:linked_project]
      @linked_package = params[:linked_package]
      @target_package = params[:target_package]
      flash.now[:error] = "Unable to find package '#{params[:linked_package]}' in" +
        " project '#{params[:linked_project]}'."
      render :action => "new_link"
      return
    end

    target_package = params[:target_package]
    target_package = params[:linked_package] if params[:target_package].blank?
      
    package = Package.new( :name => target_package, :project => params[:project] )
    package.title.data.text = linked_package.title

    description = "This package is based on the package " +
      "'#{params[:linked_package]}' from project " +
      "'#{params[:linked_project]}'.\n\n"

    description += linked_package.description.data.text if linked_package.description.data.text
    package.description.data.text = description

    unless package.save
      flash[:note] = "Failed to save package '#{package}'"
      redirect_to :controller => 'project', :action => 'show',
        :project => params[:project]
    else
      flash[:note] = "Successfully linked package '#{params[:linked_package]}'"
      redirect_to :controller => 'project', :action => 'show',
        :project => params[:project]

      logger.debug "link params: #{params[:linked_project]}, #{params[:linked_package]}"
      link = Link.new( :project => params[:project],
        :package => target_package, :linked_project => params[:linked_project], :linked_package => params[:linked_package] )
      link.save
    end
  end

  def save
    @package.title.data.text = params[:title]
    @package.description.data.text = params[:description]
    if @package.save
      flash[:note] = "Package '#{@package.name}' was saved successfully"
    else
      flash[:note] = "Failed to save package '#{@package.name}'"
    end
    redirect_to :action => 'show', :project => params[:project], :package => params[:package]
  end

  def remove
    project_name = params[:project]
    package_name = params[:package]
    begin
      FrontendCompat.new.delete_package :project => project_name, :package => package_name
      flash[:note] = "Package '#{package_name}' was removed successfully from project '#{project_name}'"
    rescue Object => e
      flash[:note] = "Failed to remove package '#{package_name}' from project '#{project_name}'"
    end
    redirect_to :controller => 'project', :action => 'show', :project => project_name
  end

  def add_file
    begin
      Link.find( :project => @project.name, :package => @package.name )
      @package_is_link = true
    rescue
      @package_is_link = false
    end
  end

  def save_file
    file = params[:file]
    file_url = params[:file_url]
    filename = params[:filename]

    if !file.blank?
      # we are getting an uploaded file
      filename = file.original_filename if filename.empty?
    elsif not file_url.empty?
      # we have a remote file uri
      begin
        uri = URI::parse file_url
        begin
          file = open uri
        rescue OpenURI::HTTPError
          flash[:error] = "Error retrieving URI '#{uri}'."
          redirect_to :action => 'add_file', :project => params[:project], :package => params[:package]
          return
        end
        filename = uri.path.sub /\/.*\//, '' if filename.empty?
        if filename.empty? or filename == '/'
          flash[:error] = 'Invalid filename / file.'
          redirect_to :action => 'add_file', :project => params[:project], :package => params[:package]
          return
        end
      rescue URI::InvalidURIError
        flash[:error] = 'Invalid URI for remote file.'
        redirect_to :action => 'add_file', :project => params[:project], :package => params[:package]
        return
      end
    else
      flash[:error] = 'No file or URI given.'
      redirect_to :action => 'add_file', :project => params[:project], :package => params[:package]
      return
    end

    # extra escaping of filename (workaround for rails bug)
    filename = URI.escape filename, "+"

    logger.debug "controller: starting to add file: '#{filename}'"
    @package.save_file :file => file, :filename => filename

    if params[:addAsPatch]
      link = Link.find( :project => @project, :package => @package )
      link.add_patch filename
      link.save
    end

    redirect_to :action => :show, :project => @project, :package => @package
  end

  def remove_file
    if not params[:filename]
      flash[:note] = "Removing file aborted: no filename given."
      redirect_to :action => :show, :project => params[:project], :package => params[:package]
    end
    filename = params[:filename]
    # extra escaping of filename (workaround for rails bug)
    escaped_filename = URI.escape filename, "+"
    
    
    if @package.remove_file escaped_filename
      flash[:note] = "File '#{filename}' removed successfully"
    else
      flash[:note] = "Failed to remove file '#{filename}'"
    end
    redirect_to :action => :show, :project => @project, :package => @package
  end


  def save_person
    if not params[:userid]
      flash[:error] = "Login missing"
      redirect_to :action => :add_person, :project => @project, :package => @package, :role => params[:role]
      return
    end
    begin
      user = Person.find( :login => params[:userid] )
      logger.debug "found user: #{user.inspect}"
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "Unknown user '#{params[:userid]}'"
      redirect_to :action => :add_person, :project => project_name, :package => params[:package], :role => params[:role]
      return
    end
    @package.add_person( :userid => params[:userid], :role => params[:role] )
    if @package.save
      flash[:note] = "added user #{params[:userid]}"
    else
      flash[:note] = "Failed to add user '#{params[:userid]}'"
    end
    redirect_to :action => :show, :package => @package, :project => @project
  end


  def remove_person
    if not params[:userid]
      flash[:note] = "User removal aborted, no user id given!"
      redirect_to :action => :show, :package => params[:package], :project => params[:project]
      return
    end
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
    @project = params[:project]
    @package = params[:package]
    @filename = params[:file]

    @file = frontend.get_source( :project => @project,
     :package => @package, :filename => @filename )
  end


  def save_modified_file
    project = params[:project]
    package = params[:package]
    filename = params[:filename]
    file = params[:file]

    file.gsub!( /\r\n/, "\n" )
    frontend.put_file( file, :project => project, :package => package,
      :filename => filename )
    flash[:note] = "Successfully saved file."
    redirect_to :action => :show, :package => package, :project => project
  end


  def live_build_log
    @project = params[:project]
    @package = params[:package]
    @arch = params[:arch]
    @repo = params[:repository]

    begin
      @log_chunk = frontend.get_log_chunk( @project, @package, @repo, @arch )

      @offset = @log_chunk.length
      @log_chunk = CGI.escapeHTML(@log_chunk);
      @log_chunk.gsub!("\n","<br/>")
    rescue ActiveXML::Transport::Error => ex
      @log_chunk = "No log available."
      return
      # TODO: Check correctly for availability of log
      code = ex.message.root.elements['code']
      if code && code.text == "404"
        @log_chunk = "No live log available"
      else
        raise
      end
    end
  end

  def update_build_log
    @project = params[:project]
    @package = params[:package]
    @arch = params[:arch]
    @repo = params[:repository]
    @offset = params[:offset].to_i

    begin
      @log_chunk = frontend.get_log_chunk( @project, @package, @repo, @arch, @offset )

      if( @log_chunk.length == 0 )
        @finished = true
      else
        @offset += @log_chunk.length
        @log_chunk = CGI.escapeHTML(@log_chunk);
        @log_chunk.gsub!("\n","<br/>")
      end

    rescue ActiveXML::Transport::NotFoundError => ex
      @log_chunk = "No live log available"
      @finished = true

    rescue Timeout::Error => ex
      @log_chunk = ""
    end

    render :update do |page|
      if @finished
        page.replace_html 'status', "Build finished"
      else
        page.replace_html 'status', "Updating..."
        page.insert_html :bottom, 'log_space', @log_chunk
        page.delay(2) do
          page << remote_function( :url => {:action => :update_build_log, :package => @package, :project => @project, :arch => @arch, :repository => @repo, :offset => @offset} )
        end
      end
    end
  end

  def trigger_rebuild
    project = params[:project]
    if ( !project )
      flash[:error] = "Project name missing."
      redirect_to :controller => "project", :action => 'list_public'
      return
    end

    package = params[:package]
    if ( !package )
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
      frontend.rebuild options
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "No repository defined"
      redirect_to :controller => "project", :action => :add_target_simple, :project => project
      return
    end

    logger.debug( "Triggered Rebuild for #{package}, options=#{options.inspect}" )

    if  params[:redirect] == 'monitor'
      controller = 'project'
      action = 'monitor'
      @message = "Triggered rebuild for package #{package}."
    else
      controller = 'package'
      action = 'show'
      @message = "Triggered rebuild."
    end

    if request.get?
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
    return false unless @package = Package.find( params[:package], :project => params[:project] )

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
    return false unless @package = Package.find( params[:package], :project => params[:project] )

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
    return false unless @package = Package.find( params[:package], :project => params[:project] )

    all_files = get_files params[:project], params[:package]
    all_files.each do |file|
      @specfile_name = file[:name] if file[:name].grep(/\.spec/) != []
    end
    specfile_content = frontend.get_source(
      :project => params[:project], :package => params[:package], :filename => @specfile_name
    )

    description = []
    lines = specfile_content.split /\n/
    line = lines.shift until line =~ /^%description\s*$/
    description << lines.shift until description.last =~ /^%/
    # maybe the above end-detection of the description-section could be improved like this:
    # description << lines.shift until description.last =~ /^%\{?(debug_package|prep|pre|preun|....)/
    description.pop

    render :text => description.join("\n")
    logger.debug "imported description from spec file"
  end


  def edit_disable_xml
    return false unless @package = Package.find( params[:package], :project => params[:project] )
    return false unless @project = Project.find( params[:project] )
    @xml = @package.get_disable_tags
    render :partial => 'edit_disable_xml'
  end


  def save_disable_xml
    return false unless @package = Package.find( params[:package], :project => params[:project] )
    unless @package.replace_disable_tags( params[:xml] )
      flash[:error] = 'Error saving your input (invalid XML?).'
    end
    redirect_to :action => 'show', :project => params[:project], :package => params[:package]
  end


  def reload_buildstatus
    @buildresult = Buildresult.find( :project => @project, :package => @package, :view => ['status', 'binarylist'] )
    render :partial => 'buildstatus'
  end


  def set_url_form
    # default url for form
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
    #redirect_to :action => "show", :project => params[:project], :package => params[:package]
  end


  def remove_url
    @package.remove_url
    redirect_to :action => "show", :project => params[:project], :package => params[:package]
  end


  def rate
    @project = params[:project]
    @package = params[:package]
    @score = params[:score] or return
    rating = Rating.new( :score => @score,
      :project => @project, :package => @package
    )
    rating.save
    @rating = Rating.find(
      :project => @project, :package => @package
    )
    render :partial => 'shared/rate'
  end


  # update package flags
  def update_flag
    begin
      #the flag matrix will also be initialized on access, so we can work on it
      @package = Package.find(params[:package], :project => params[:project])
      if @package.complex_flag_configuration? params[:flag_name]
        raise RuntimeError.new("Your flag configuration seems to be too complex to be saved through this interface. Please use OSC.")
      end

      @package.replace_flags(params)
    rescue RuntimeError => exception
      @error = exception
      logger.debug "[PACKAGE:] Flag-Update-Error: flag configuration is rejected to be saved because of its complexity."
    rescue  ActiveXML::Transport::Error => exception
      #rescue_action_in_public exception
      @error = exception
      logger.debug "[PACKAGE:] Flag-Update-Error: #{@error}"
    end

    @flag = @package.send("#{params[:flag_name]}"+"flags")[params[:flag_id].to_sym]
  end


  def flags_for_experts
    render :template => "flag/package_flags_for_experts"
  end


  private

  def check_params
    if params[:project]
      unless valid_project_name?( params[:project] )
        flash[:error] = "Invalid project name, may only contain alphanumeric characters"
        redirect_to :action => :error
      end
    end
    if params[:role]
      unless valid_role_name?( params[:role] )
        flash[:error] = "Invalid role name"
        redirect_to :action => :error
      end
    end
  end


  def get_files( project, package )
    # files whose name end in the following extensions should not be editable
    no_edit_ext = %w{ .bz2 .exe .gem .gif .gz .jar .jpg .jpeg .ogg .ps .pdf .png .rpm .tar .tgz .xpm .zip }

    files = []
    dir = Directory.find( :project => project, :package => package )

    dir.each_entry do |entry|
      file = Hash[*[:name, :size, :mtime, :md5].map {|x| [x, entry.send(x.to_s)]}.flatten]
      file[:ext] = Pathname.new(file[:name]).extname
      file[:editable] = (not no_edit_ext.include? file[:ext].downcase) and file[:size].to_i < 2**20  # max. 1 MB
      files << file
    end
    return files
  end

  def require_project
    begin
      raise ActiveXML::Transport::NotFoundError if params[:project].nil?
      @project = Project.find( params[:project] )
    rescue ActiveXML::Transport::NotFoundError => e
      logger.error "Project #{params[:project]} not found: #{e.message}"
      flash[:error] = "Project not found: \"#{params[:project]}\""
      redirect_to :controller => "project", :action => "list_public" and return
    end
  end

  def require_package
    @project ||= params[:project]
    begin
      raise ActiveXML::Transport::NotFoundError if params[:package].nil?
      @package = Package.find( params[:package], :project => @project )
    rescue ActiveXML::Transport::NotFoundError => e
      logger.error "Package #{params[:package]} not found: #{e.message}"
      flash[:error] = "Package \"#{params[:package]}\" not found in project \"#{params[:project]}\""
      redirect_to :controller => "project", :action => :show, :project => @project and return
    end
  end

end


