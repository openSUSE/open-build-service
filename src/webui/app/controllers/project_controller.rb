class ProjectController < ApplicationController

  before_filter :require_project, :only => [:delete, :buildresult, :view, 
    :trigger_rebuild, :edit, :save, :add_target_simple, :save_target, 
    :remove_person, :save_person, :add_person, :remove_target, :toggle_watch, :list_packages,
    :update_target, :edit_target, :show, :monitor]
  before_filter :require_prjconf, :only => [:edit_prjconf, :prjconf ]

  def index
    redirect_to :action => 'list_public'
  end

  def list_all
    list :with_homes
  end

  def list_public
    # load important projects:
    predicate = "[attribute/@name='OBS:VeryImportantProject']"
    @important_projects = Collection.find :id, :what => "project", :predicate => predicate
    list :without_homes
  end

  def list(mode=:without_homes)
    filterstring = params[:projectsearch] || params[:searchtext] || ''

    if !filterstring.empty?
      predicate = "contains(@name, '#{filterstring}')"
    else
      predicate = ''
    end
    if mode==:without_homes
      predicate += " and " if !predicate.empty?
      predicate += "not(starts-with(@name,'home:'))"
    end
    result = Collection.find :id, :what => "project", :predicate => predicate
    @projects = result.each.sort {|a,b| a.name.downcase <=> b.name.downcase}
    if request.xhr?
      render :partial => 'search_project', :locals => {:project_list => @projects}
    else
      if @projects.length == 1
        redirect_to :action => 'show', :project => @projects.first
      end
    end
  end
  private :list

  def list_my
    @user ||= Person.find( :login => session[:login] )
    if @user.has_element? :watchlist
      #extract a list of project names and sort them case insensitive
      @watchlist = @user.watchlist.each_project.map {|p| p.name }.sort {|a,b| a.downcase <=> b.downcase }
    end

    @iprojects = @user.involved_projects.each.map {|x| x.name}.uniq.sort
    @ipackages = Hash.new
    pkglist = @user.involved_packages.each.reject {|x| @iprojects.include?(x.project)}
    pkglist.sort(&@user.method('packagesorter')).each do |pack|
      @ipackages[pack.project] ||= Array.new
      @ipackages[pack.project] << pack.name if !@ipackages[pack.project].include? pack.name
    end

  end


  def remove_watched_project
    project = params[:project]
    @user ||= Person.find( session[:login] )
    logger.debug "removing watched project '#{project}' from user '#@user'"
    @user.remove_watched_project project
    @user.save

    if @user.has_element? :watchlist
      @watchlist = @user.watchlist.each_project.map {|p| p.name }.sort {|a,b| a.downcase <=> b.downcase }
    end

    render :partial => 'watch_list'
  end

  def new
    @namespace = params[:ns]
    @project_name = params[:project]
    if params[:ns] == "home:#{session[:login]}"
      begin
        @project = Project.find params[:ns]
      rescue ActiveXML::Transport::NotFoundError
        flash[:note] = "Your home project doesn't exist yet. You can create it now by entering some" +
          " descriptive data and press the 'Create Project' button."
        redirect_to :action => :new, :project => params[:ns] and return
      end
    end
    if @project_name =~ /home:(.+)/
      @project_title = "#$1's Home Project"
    else
      @project_title = ""
    end
  end

  def show
    @email_hash = Hash.new
    @project.each_person do |person|
      @email_hash[person.userid.to_s] = Person.find_cached( person.userid ).email.to_s
    end
    @subprojects = Collection.find :id, :what => "project", :predicate => "starts-with(@name,'#{params[:project]}:')"
    @arch_list = arch_list
    @tags, @user_tags_array = get_tags(:project => params[:project], :package => params[:package], :user => session[:login])
    @rating = Rating.find( :project => params[:project] )
    @attributes = Attributes.find(:project, :project => params[:project])
  end

  def buildresult
    @arch_list = arch_list
    @buildresult = Buildresult.find( :project => params[:project], :view => 'summary' )
    render :partial => 'inner_repo_table', :locals => {:has_data => true}
  end


  def delete
    valid_http_methods :post
    @confirmed = params[:confirmed]
    if @confirmed == "1"
      begin
        if params[:force] == "1"
          @project.delete :force => 1
        else
          @project.delete
        end
      rescue ActiveXML::Transport::Error => err
        @error, @code, @api_exception = ActiveXML::Transport.extract_error_message err
        logger.error "Could not delete project #{@project}: #{@error}"
      end
    end
  end

  def arch_list
    if @arch_list.nil?
      tmp = []
      @project.each_repository do |repo|
        tmp += repo.archs
      end
      @arch_list = tmp.sort.uniq
    end
    return @arch_list
  end

  def get_tags(params)
    user_tags = Tag.find(:project => params[:project], :user => params[:user])
    tags = Tag.find(:tags_by_object, :project => params[:project])
    user_tags_array = []
    user_tags.each_tag do |tag|
        user_tags_array << tag.name
    end
    return tags, user_tags_array
  end

  def view
    @packages = []
    Package.find( :all, :project => params[:project] ).each_entry do |package|
      @packages << package.name
    end

    @created_timestamp = LatestAdded.find( :specific,
      :project => @project ).project.created
    @updated_timestamp = LatestUpdated.find( :specific,
      :project => @project ).project.updated

    #@tags = Tag.find(:user => session[:login], :project => @project.name)

    #TODO not efficient, @user_tags_array is needed because of shared _tags_ajax.rhtml
    @tags, @user_tags_array = get_tags(:project => params[:project], :package => params[:package], :user => session[:login])

    @downloads = Downloadcounter.find( :project => @project )
    @rating = Rating.find( :project => @project )
    @activity = ( MostActive.find( :specific, :project => @project,
      :package => @package).project.activity.to_f * 100 ).round.to_f / 100
  end


  def show_projects_by_tag
    @collection = Collection.find(:tag, :type => "_projects", :tagname => params[:tag])
    @projects = []
    @collection.each_project do |project|
      @projects << project
    end
    @tagcloud ||= Tagcloud.new(:user => session[:login], :tagcloud => session[:tagcloud])
    render :action => "../tag/list_objects_by_tag"
  end


  def flags_for_experts
    @project = Project.find(params[:project])
    render :template => "flag/project_flags_for_experts"
  end

  #update project flags
  def update_flag
    begin
      #the flag matrix will also be initialized on access, so we can work on it
      @project = Project.find(params[:project])
      if @project.complex_flag_configuration? params[:flag_name]
        raise RuntimeError.new("Your flag configuration seems to be too complex to be saved through this interface. Please use OSC.")
      end

      @project.replace_flags(params)
    rescue RuntimeError => exception
      @error = exception
      logger.debug "[PROJECT:] Flag-Update-Error: flag configuration is rejected to be saved because of its complexity."
    rescue  ActiveXML::Transport::Error => exception
      #rescue_action_in_public exception
      @error = exception
      logger.debug "[PROJECT:] Error: #{@error}"
    end

    @flag = @project.send("#{params[:flag_name]}"+"flags")[params[:flag_id].to_sym]

  end

  def enable_arch
    @project = Project.find(params[:project])
    @arch_list = arch_list
    repo = @project.repository[params[:repo]]
    repo.add_arch params[:arch]
    if @project.save
      render :partial => 'repository_item', :locals => { :repo => repo, :has_data => true }
    else
      render :text => 'enabling architecture failed'
    end
  end

  def edit_target
    repo = @project.repository[params[:repo]]
    @arch_list = arch_list
    render :partial => 'repository_edit_form', :locals => { :repo => repo }
  end

  def update_target
    repo = @project.repository[params[:repo]]
    repo.name = params[:name]
    repo.archs = params[:arch].to_a
    if @project.save
      @arch_list = arch_list
      render :partial => 'repository_item', :locals => { :repo => repo, :has_data => true }
    else
      render :text => 'updating target failed'
    end
  end


  # render the input form for tags
  def add_tag_form
    @project = params[:project]
    render :partial => "add_tag_form"
  end


  def add_tag
    logger.debug "New tag(s) #{params[:tag]} for project #{params[:project]}."
    tags = []
    tags << params[:tag]
    old_tags = Tag.find(:user => session[:login], :project => params[:project])
    old_tags.each_tag do |tag|
      tags << tag.name
    end
    logger.debug "[TAG:] saving tags #{tags.join(" ")} for project #{params[:project]}."

    @tag_xml = Tag.new(:project => params[:project], :tag => tags.join(" "), :user => session[:login])
    begin
      @tag_xml.save

    rescue ActiveXML::Transport::Error => exception
      rescue_action_in_public exception
      @error = CGI::escapeHTML(@message)
      logger.debug "[TAG:] Error: #{@message}"
      @unsaved_tags = true
    end

    @tags, @user_tags_array = get_tags(:user => session[:login], :project => params[:project])

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

  def list_packages
    @matching_packages = []
    Package.find( :all, :project => params[:project] ).each_entry do |package|
      @matching_packages << package.name
    end
    render :partial => "search_package"
  end

  def save_new
    @namespace = params[:ns]
    @project_title = params[:title]
    @project_description = params[:description]
    @new_project_name = params[:name]
    if params[:ns]
       project_name = params[:ns].strip + ":" + @new_project_name.strip
    else
       project_name = @new_project_name.strip
    end

    if !valid_project_name? project_name
      flash.now[:error] = "Invalid project name '#{project_name}'."
      render :action => "new" and return
    end

    if Project.exists? project_name
      flash.now[:error] = "Project '#{project_name}' already exists."
      render :action => "new" and return
    end

    Person.find( session[:login] )
    #store project
    @project = Project.new(:name => project_name)
    @project.title.text = params[:title]
    @project.description.text = params[:description]
    @project.add_person :userid => session[:login], :role => 'maintainer'
    @project.add_person :userid => session[:login], :role => 'bugowner'
    begin
      if @project.save
        flash[:note] = "Project '#{@project}' was created successfully"
        redirect_to :action => 'show', :project => project_name and return
      else
        flash[:error] = "Failed to save project '#{@project}'"
      end
    rescue ActiveXML::Transport::ForbiddenError => err
      flash[:error] = "You lack the permission to create the project '#{@project}'. " +
        "Please create it in your home:%s namespace" % session[:login]
      redirect_to :action => 'new', :ns => "home:" + session[:login] and return
    end
    redirect_to :action => 'new'
  end


  def trigger_rebuild
    if request.get?
      # non ajax-request
      if @project.save
        flash[:note] = "Triggered rebuild"
      else
        flash[:error] = "Failed to trigger rebuild"
      end
      redirect_to :action => 'show', :project => params[:project]
    else
      # ajax-request
      if @project.save
        @message = "Triggered rebuild"
      else
        @message = "Failed to trigger rebuild"
      end
    end
  end


  def save
    if ( !params[:title] )
      flash[:error] = "Title must not be empty"
      redirect_to :action => 'edit', :project => params[:project]
      return
    end

    @project.title.text = params[:title]
    @project.description.text = params[:description]

    if @project.save
      flash[:note] = "Project '#{@project}' was saved successfully"
    else
      flash[:error] = "Failed to save project '#{@project}'"
    end

    redirect_to :action => 'show', :project => @project
  end

  def add_repository
    @project = params[:project]
  end

  def receive_repository
    @id = params[:id]
  end

  def update_project_list
    if params[:filter]
      @project_list = Collection.find :id, :what => "project", :predicate => "contains(@name,'#{params[:filter]}')"
    else
      @project_list = Project.find :all
    end
    render :partial => "project_list"
      
  end

  def update_repolist
    logger.debug "updating repolist for project #{params[:project]}"
    project = Project.find params[:project]
    if project.has_element? :repository
      render :partial => "repository_list", :locals => {:project => params[:project], :repos => project.each_repository}
    else
      render :text => "<b>No repositories found</b>"
    end
  end


  def add_target
    @platforms = Platform.find( :all ).each_entry.map {|p| p.name.to_s}

    #TODO: don't hardcode
    @priority_namespaces = %{
      Mandriva
      openSUSE
      SUSE
      RedHat
      Fedora
      Debian
      Ubuntu
    }

    def @priority_namespaces.include_ns?(projname)
      nslist = projname.split(/:/)
      return false if nslist.length < 2
      return false unless self.include? nslist[0]
      return true
    end

    @platforms.sort! do |a,b|
      if @priority_namespaces.include_ns? a
        if @priority_namespaces.include_ns? b
          a.downcase <=> b.downcase
        else
          -1
        end
      else
        if @priority_namespaces.include_ns? b
          1
        else
          a.downcase <=> b.downcase
        end
      end
    end

    @project = params[:project]
    @targetname = params[:targetname]
    @platform = params[:platform]
  end

  def save_target
    platform = params[:platform]
    arch = params[:arch]
    targetname = params[:targetname]
    targetname = "standard" if targetname.blank?

    if !valid_platform_name? targetname
      flash[:error] = "Illegal target name."
      redirect_to :action => :add_target, :project => @project, :targetname => targetname, :platform => platform
      return
    end

    if platform.blank?
      flash[:error] = "Please select a target platform."
      redirect_to :action => :add_target, :project => @project, :targetname => targetname, :platform => platform
      return
    end

    @project.add_repository :reponame => targetname, :platform => platform, :arch => arch

    begin
      if @project.save
        flash[:note] = "Target '#{platform}' was added successfully"
      else
        flash[:error] = "Failed to add target '#{platform}'"
      end
    rescue ActiveXML::Transport::Error => e
        message, code, api_exception = ActiveXML::Transport.extract_error_message e
        flash[:error] = "Failed to add target '#{platform}' " + message
    end

    redirect_to :action => :show, :project => @project
  end

  def remove_target
    if not params[:target]
      flash[:error] = "Target removal failed, no target selected!"
      redirect_to :action => :show, :project => params[:project]
    end
    @project.remove_repository params[:target]

    if @project.save
      flash[:note] = "Target '#{params[:target]}' was removed"
    else
      flash[:error] = "Failed to remove target '#{params[:target]}'"
    end

    redirect_to :action => :show, :project => @project
  end


  def save_person
    if not params[:userid]
      flash[:error] = "Login missing"
      redirect_to :action => :add_person, :project => params[:project], :role => params[:role]
      return
    end
    begin
      user = Person.find( :login => params[:userid] )
    rescue ActiveXML::NotFoundError
      flash[:error] = "Unknown user with id '#{params[:userid]}'"
      redirect_to :action => :add_person, :project => params[:project], :role => params[:role]
      return
    end
    logger.debug "found user: #{user.inspect}"
    @project.add_person( :userid => params[:userid], :role => params[:role] )

    if @project.save
      flash[:note] = "added user #{params[:userid]}"
    else
      flash[:error] = "Failed to add user '#{params[:userid]}'"
    end

    redirect_to :action => :show, :project => @project
  end

  def remove_person
    if not params[:userid]
      flash[:note] = "User removal aborted, no user id given!"
      redirect_to :action => :show, :project => params[:project]
      return
    end
    @project.remove_persons( :userid => params[:userid], :role => params[:role] )

    if @project.save
      flash[:note] = "removed user #{params[:userid]}"
    else
      flash[:error] = "Failed to remove user '#{params[:userid]}'"
    end

    redirect_to :action => :show, :project => params[:project]
  end

  def monitor
    @name_filter = params[:pkgname]
    @lastbuild_switch = params[:lastbuild]
    if params[:defaults]
      defaults = (Integer(params[:defaults]) rescue 1) > 0
    else
      defaults = true
    end
    @avail_status_values = 
      ['succeeded','failed','expansion error','broken','blocked', 'disabled',
      'scheduled','building','dispatching','finished','excluded','unknown'].sort
    @status_filter = []
    @avail_status_values.each { |s|
      if defaults || (params.has_key?(s) && params[s])
	@status_filter << s
      end
    }
    
    @avail_arch_values = []
    @avail_repo_values = []

    @project.repositories.each { |r|
      @avail_repo_values << r.name
      @avail_arch_values << r.archs if r.archs
    }
    @avail_arch_values = @avail_arch_values.flatten.uniq.sort
    @avail_repo_values = @avail_repo_values.flatten.uniq.sort

    @arch_filter = []
    @avail_arch_values.each { |s|
      if defaults || (params.has_key?('arch_' + s) && params['arch_' + s])
	@arch_filter << s
      end
    }
   
    @repo_filter = []
    @avail_repo_values.each { |s|
      if defaults || (params.has_key?('repo_' + s) && params['repo_' + s])
	@repo_filter << s
      end
    }

    begin
      @buildresult = Buildresult.find( :project => @project, :view => 'status', :code => @status_filter,
                     @lastbuild_switch.blank? ? nil : :lastbuild => '1', :arch => @arch_filter, :repo => @repo_filter )
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "No build results for project '#{@project}'"
      redirect_to :action => :show, :project => params[:project]
      return
    end

    if not @buildresult.has_element? :result
      @buildresult_unavailable = true
      return
    end

    @repohash = Hash.new
    @statushash = Hash.new
    @packagenames = Array.new

    @buildresult.each_result do |result|
      @resultvalue = result
      repo = result.repository
      arch = result.arch

      next unless @repo_filter.include? repo
      @repohash[repo] ||= Array.new
      next unless @arch_filter.include? arch
      @repohash[repo] << arch

      @statushash[repo] ||= Hash.new
      @statushash[repo][arch] = Hash.new

      stathash = @statushash[repo][arch]
      result.each_status do |status|
        stathash[status.package] = status
      end

     @packagenames << stathash.keys

    end
    @packagenames = @packagenames.flatten.uniq.sort

    ## Filter for PackageNames #### 
    @packagenames.reject! {|name| not filter_matches?(name,@name_filter) } if not @name_filter.blank?

  end

  def filter_matches?(input,filter_string)
    result = false
    filter_string.gsub!(/\s*/,'')
    filter_string.split(',').each { |filter|
      no_invert = filter.match(/(^!?)(.+)/)
      if no_invert[1] == '!'
        result = input.include?(no_invert[2]) ? result : true
      else
        result = input.include?(no_invert[2]) ? true : result
      end
    }
    return result
  end


  def toggle_watch
    @user ||= Person.find( :login => session[:login] )
    if @user.watches? @project.name
      @user.remove_watched_project @project.name
    else
      @user.add_watched_project @project.name
    end
    @user.save
    render :partial => "watch_link"
  end


  def rate
    @project = params[:project]
    @score = params[:score] or return
    rating = Rating.new( :score => @score, :project => @project )
    rating.save
    @rating = Rating.find( :project => @project )
    render :partial => 'shared/rate'
  end

  def prjconf
  end
  
  def edit_prjconf
  end

  def save_prjconf
    frontend.put_file(params[:config], :project => params[:project], :filename => '_config')
    flash[:note] = "Project Config successfully saved"
    redirect_to :action => :prjconf, :project => params[:project]
  end

  private


  def paginate_collection(collection, options = {})
    options[:page] = options[:page] || params[:page] || 1
    default_options = {:per_page => 20, :page => 1}
    options = default_options.merge options

    pages = Paginator.new self, collection.size, options[:per_page], options[:page]
    first = pages.current.offset
    last = [first + options[:per_page], collection.size].min
    slice = collection[first...last]
    return [pages, slice]
  end

  def filter_packages( project, filterstring )
    result = Collection.find :id, :what => "package",
      :predicate => "@project='#{project}' and contains(@name,'#{filterstring}')"
    return result.each.map {|x| x.name}
  end


  def require_project
    if !valid_project_name? params[:project] 
      unless request.xhr?
         flash[:error] = "#{params[:project]} is not a valid project name"
         redirect_to :controller => "project", :action => "list_public" and return
      else
         render :text => 'Not a valid project name', :status => 404 and return
      end
    end
    begin
      @project = Project.find( params[:project] )
    rescue ActiveXML::Transport::NotFoundError => e
      if params[:project] == "home:" + session[:login]
        # checks if the user is registered yet
        Person.find( :login => session[:login] )
        flash[:note] = "Your home project doesn't exist yet. You can create it now by entering some" +
          " descriptive data and press the 'Create Project' button."
        redirect_to :action => :new, :project => "home:" + session[:login] and return
      end
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public"
      return
    end
  end


  def require_prjconf
    if !valid_project_name? params[:project]
      flash[:error] = "#{params[:project]} is not a valid project name"
      redirect_to :controller => "project", :action => "list_public"
      return
    end

    @project = params[:project]
    begin
      @config = frontend.get_source(:project => params[:project], :filename => '_config')
    rescue ActiveXML::Transport::NotFoundError => e
      flash[:error] = "Project not found: #{params[:project]}" 
      redirect_to :controller => "project", :action => "list_public"
    end
  end

end
