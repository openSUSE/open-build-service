class ProjectController < ApplicationController 
  model :project, :package, :result

  before_filter :check_parameter_project, :except =>
    [ :list_all, :list_public, :list_my, :new, :save_new, :save, :index, :refresh_monitor,
      :toggle_watch ]

  def list_all
    projectlist = Project.find(:all).each_entry.sort do |a,b|  
      a.name.downcase <=> b.name.downcase
    end

    @project_pages, @projects = paginate_collection( projectlist )
  end

  def list_public
    projectlist = Project.find(:all).each_entry.sort do |a,b|  
      a.name.downcase <=> b.name.downcase 
    end

    projectlist.reject! do |p|
      p.name.to_s =~ /^home:/
    end
    
    @project_pages, @projects = paginate_collection( projectlist )
  end

  def list_my
    @projects = Project.find(:all).each_entry
    logger.debug "Have this session login: #{session[:login]}"
    @user = Person.find( :login => session[:login] )
    @watchlist = @user.watchlist if @user.has_element? :watchlist
  end

  def new
    @project_name = params[:project]
    if @project_name =~ /home:(.*)/
      @project_title = "#$1's Home Project" 
    else
      @project_title = ""
    end
  end

  def show
# @user = Person.find( :login => session[:login] ) if session[:login]
    begin
      @project = Project.find( params[:project] )
    rescue ActiveXML::Transport::NotFoundError
      home_project = "home:" + session[:login]
      if params[:project] == home_project
        flash[:note] = "Home project doesn't exist yet. You can create it now by entering some" +
          " descriptive data and press the 'Create Project' button."
        redirect_to :action => :new, :project => home_project
      else
        flash[:error] = "Project #{params[:project]} doesn't exist."
        redirect_to :action => list_public
      end
      return
    end

    @project_name = @project.name
    session[:project] = @project.name

    begin
      result = Result.find( :project => params[:project] )
      if ( result )
        @status = result.status.code
        @package_counts = Hash.new
        result.status.each_packagecount do |c|
          @package_counts[ c.state ] = c
        end

        @status_map = Hash.new
        result.each_repositoryresult do |r|
          @status_map[ r.name ] = Hash.new
          r.each_archresult do |a|
            @status_map[ r.name ][ a.arch ] = a.status.code
          end
        end
      end
    rescue ActiveXML::Transport::NotFoundError
    end
  end

  def save_new
    logger.debug( "save_new" )
  
    if !valid_project_name?( params[:name] )
      flash[:error] = "Invalid project name '#{params[:name]}'."
      redirect_to :action => "new"
    else
      #store project
      @project = Project.new( :name => params[:name] )

      @project.title.data.text = params[:title]
      @project.description.data.text = params[:description]
      @project.add_person :userid => session[:login], :role => 'maintainer'

      if @project.save
        flash[:note] = "Project '#{@project}' was created successfully"
      else
        flash[:note] = "Failed to save project '#{@project}'"
      end

      redirect_to :action => 'show', :project => params[:name]
    end
  end

  def edit
    @project = Project.find( params[:project] )
    session[:project] = @project.name
  end

  def trigger_rebuild
    @project = Project.find( params[:project] )
    if @project.save
      flash[:note] = "Triggered rebuild"
    else
      flash[:note] = "Failed to trigger rebuild"
    end
    redirect_to :action => 'show', :project => params[:project]
  end

  def save
    @project = Project.find( session[:project] )

    if ( !params[:title] )
      flash[:error] = "Title must not be empty"
      redirect_to :action => 'edit', :project => params[:project]
      return
    end

    @project.title.data.text = params[:title]
    @project.description.data.text = params[:description]

    if @project.save
      flash[:note] = "Project '#{@project}' was saved successfully"
    else
      flash[:note] = "Failed to save project '#{@project}'"
    end
    session[:project] = nil

    redirect_to :action => 'show', :project => @project
  end

  def add_target
    @platforms = Platform.find( :all ).each_entry.map {|p| p.name.to_s}
    
    @platforms.sort! do |a,b|
      a.downcase <=> b.downcase
    end

    @project = Project.find( params[:project] )
    @targetname = params[:targetname]
    @platform = params[:platform]
    session[:project] = @project.name
  end

  def save_target
    @project = Project.find( session[:project] )
    platform = params[:platform]
    arch = params[:arch]
    targetname = params[:targetname]
    targetname = "standard" if not targetname or targetname.empty?

    if targetname =~ /\s/
      flash[:note] = "Target name may not contain spaces"
      redirect_to :action => :add_target, :project => @project, :targetname => targetname, :platform => platform
      return
    end

    @project.add_target :targetname => targetname, :platform => platform,
      :arch => arch

    if @project.save
      flash[:note] = "Target '#{platform}' was added successfully"
    else
      flash[:note] = "Failed to add target '#{platform}'"
    end

    redirect_to :action => :show, :project => @project
  end

  def remove_target
    if not params[:target]
      flash[:error] = "Target removal failed, no target selected!"
      redirect_to :action => :show, :project => params[:project]
    end

    @project = Project.find( params[:project] )
    @project.remove_target params[:target]

    if @project.save
      flash[:note] = "Target '#{params[:target]}' was removed"
    else
      flash[:note] = "Failed to remove target '#{params[:target]}'"
    end

    redirect_to :action => :show, :project => @project
  end

  def add_person
    @project = Project.find( params[:project] )
    session[:project] = @project.name
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
    
    @project = Project.find( session[:project] )
    @project.add_person( :userid => params[:userid], :role => params[:role] )

    if @project.save
      flash[:note] = "added user #{params[:userid]}"
    else
      flash[:note] = "Failed to add user '#{params[:userid]}'"
    end

    redirect_to :action => :show, :project => @project
  end

  def remove_person
    if not params[:userid]
      flash[:note] = "User removal aborted, no user id given!"
      redirect_to :action => :show, :project => params[:project]
      return
    end
    @project = Project.find( params[:project] )
    @project.remove_persons( :userid => params[:userid], :role => params[:role] )

    if @project.save
      flash[:note] = "removed user #{params[:userid]}"
    else
      flash[:note] = "Failed to remove user '#{params[:userid]}'"
    end

    redirect_to :action => :show, :project => params[:project]
  end

  def monitor
    #@project = Project.find( params[:project] )
    #@projectresult = Result.find( :project => params[:project] )
    #@packresults = Hash.new
    #@repolist = Array.new

    #@project.each_package do |pack|
    #  @packresults[pack.name] = Hash.new
    #  @project.each_repository do |repo|
    #    @packresults[pack.name][repo.name] = Result.find( :project => params[:project], :package => pack.name, :platform => repo.name )
    #  end
    #end
    #@repolist = @projectresult.each_repositoryresult
   
    @project = params[:project] 
    @packstatus = Packstatus.find( :project => @project )

    @repohash = Hash.new
    @packstatus.each_packstatuslist do |psl|
      @repohash[psl.repository] ||= Array.new
      @repohash[psl.repository] << psl.arch
    end

    @packagenames = Array.new
    @packstatus.packstatuslist.each_packstatus do |ps|
      @packagenames << ps.name
    end
    
    session[:monitor_project] = @project
    session[:monitor_repohash] = @repohash
    session[:monitor_packnames] = @packagenames
  end

  def refresh_monitor
    render :nothing unless session[:monitor_project] and
                           session[:monitor_repohash] and
                           session[:monitor_packnames]

    @project = session[:monitor_project]
    @repohash = session[:monitor_repohash]
    @packnames = session[:monitor_packnames]

    @packstatus = Packstatus.find( :project => @project )
    
    @status = Hash.new
    @packnames.each do |pack|
      @repohash.each do |repo,archlist|
        archlist.each do |arch|
          @status["#{pack}:#{repo}:#{arch}"] = @packstatus.status_for( pack, repo, arch )
        end
      end
    end

    render :layout => false
  end

  def toggle_watch
    unless session[:login]
      render :nothing => true
      return
    end
    
    @user = Person.find( :login => session[:login] )
    @project_name = session[:project]
    
    if @user.watches? @project_name
      @user.remove_watched_project @project_name
    else
      @user.add_watched_project @project_name
    end

    @user.save

    render :partial => "watch_link"
  end

  private

  #filters
  
  def check_parameter_project
    if ( !params[:project] )
      flash[:note] = "Missing parameter 'project'"
      redirect_to :action => :list_public
    elsif !valid_project_name?( params[:project] )
      flash[:error] = "Invalid project name '#{params[:project]}'"
      redirect_to :action => :list_public
    end
  end

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

end
