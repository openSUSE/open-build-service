class PackageController < ApplicationController
  model :project, :package, :result, :link
  before_filter :check_params
  
  def show
    project = params[:project]
    if ( !project )
      flash[:error] = "Missing parameter: project name"
      redirect_to :controller => "project", :action => "list_public"
    else
      package = params[:package]
      if ( !package )
        flash[:error] = "Missing parameter: package name"
        redirect_to :controller => "project", :action => "show",
          :project => project
      else
        @project = Project.find( project )
        @package = Package.find( package, :project => project )

        @files = []
        dir = Directory.find( :project => project, :package => package )
        dir.each_entry do |file|
          @files << file.name
          if ( file.name == "_link" )
            begin
              @link = Link.find( :project => project, :package => package )
            rescue ActiveXML::Transport::NotFoundError
              @link = nil
            end
          end
        end

        session[:project_name] = project

        @results = []
        @project.each_repository do |repository|
          result = Result.find( :project => project, :package => package,
            :platform => repository.name )
          @results << result if result
        end
      end
    end
  end

  def new
    if not params[:project]
      flash[:note] = "Creating package failed: Project name missing"
      redirect_to :controller => "project", :action => "list_all"
      return
    end
    
    @project = Project.find( params[:project] )
  end

  def new_link
    if not params[:project]
      flash[:note] = "Linking package failed: Project name missing"
      redirect_to :controller => "project", :action => "list_all"
      return
    end
    
    @project = Project.find( params[:project] )
  end

  def edit
    @project = Project.find( params[:project] )
    @package = Package.find( params[:package], :project => params[:project] )
  end

  def save_new
    if not params[:project]
      flash[:note] = "Creating package failed: Project name missing"
      redirect_to :controller => "project", :action => "list_all"
      return
    end
    
    @project = Project.find( params[:project] )

    if params[:name]
      if !valid_package_name? params[:name]
        flash[:error] = "Invalid package name: '#{params[:name]}'"
        redirect_to :action => 'new', :project => params[:project]
      else
        @package = Package.new( :name => params[:name], :project => @project )

        @package.title.data.text = params[:title]
        @package.description.data.text = params[:description]

        @project.add_package @package

        if @project.save and @package.save
          if params[:createSpecFileTemplate]
            logger.debug( "CREATE SPEC FILE TEMPLATE" )
            frontend.cmd_package( @project.name, @package.name,
              "createSpecFileTemplate" )
          end

          flash[:note] = "Package '#{@package}' was created successfully"
          redirect_to :action => 'show', :project => params[:project], :package => params[:name]
        else
          flash[:note] = "Failed to save package '#{@package}'"
          redirect_to :controller => 'project', :action => 'show', :project => params[:project]
        end
      end
    end
  end

  def save_new_link
    if not params[:project]
      flash[:note] = "Linking package failed: Project name missing"
      redirect_to :controller => "project", :action => "list_all"
      return
    end
    
    @project = Project.find( params[:project] )

    begin
      linked_package = Package.find( params[:linked_package],
        :project => params[:linked_project] )
    rescue: ActiveXML::NotFoundError
      flash[:note] = "Unable to find package '#{params[:linked_package]}' in" +
        " project '#{params[:linked_project]}'."
      redirect_to :action => "new_link", :project => params[:project]
      return
    end

    package = Package.new( :name => params[:linked_package],
      :project => params[:project] )

    package.title.data.text = linked_package.title

    description = "This package is based on the package " +
      "'#{params[:linked_package]}' from project " +
      "'#{params[:linked_project]}'.\n\n"

    linked_description = linked_package.description.data.text
    if ( linked_description )
      description += linked_description
    end

    package.description.data.text = description

    @project.add_package package

    unless @project.save and package.save
      flash[:note] = "Failed to save package '#{package}'"
      redirect_to :controller => 'project', :action => 'show',
        :project => params[:project]
    else
      flash[:note] = "Successfully linked package '#{params[:linked_package]}'"
      redirect_to :controller => 'project', :action => 'show',
        :project => params[:project]

      link = Link.new( :project => params[:project], :package => params[:linked_package] )
      logger.debug "LINK: #{link.to_s}"
      link.save
    end
  end

  def save
    @package = Package.find( params[:package], :project => params[:project] )

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
    @project = Project.find( params[:project] )
    @package_name = params[:package]

    @project.remove_package @package_name
    
    if @project.save
      flash[:note] = "Package '#{@package_name}' was removed successfully from project '#{@project}'"
    else
      flash[:note] = "Failed to remove package '#{@package_name}' from project '#{@project}'"
    end
    redirect_to :controller => 'project', :action => :show, :project => params[:project]
  end

  def add_file
    @project = Project.find( params[:project] )
    @package = Package.find( params[:package], :project => params[:project] )
    session[:project] = @project.name
    session[:package] = @package.name

    begin
      Link.find( :project => @project.name, :package => @package.name )
      @package_is_link = true
    rescue
      @package_is_link = false
    end
  end

  def save_file
    @project = Project.find( session[:project] )
    @package = Package.find( session[:package], :project => @project )

    file = params[:file]
    if params[:filename].empty?
      filename = file.original_filename
    else
      filename = params[:filename]
    end

    logger.debug "controller: starting to add file: #{filename}"
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
    
    @project = params[:project]
    @package = Package.find( params[:package], :project => @project )
    filename = params[:filename]

    @package.remove_file filename

    if @package.save
      flash[:note] = "File '#{filename}' removed successfully"
    else
      flash[:note] = "Failed to remove file '#{filename}'"
    end

    redirect_to :action => :show, :project => @project, :package => @package
  end

  def add_person
    @project_name = session[:project_name]
    @package = Package.find( params[:package], :project => @project_name )
    session[:package] = @package.name
  end

  def save_person
    if not params[:userid]
      flash[:error] = "Login missing"
      redirect_to :action => :add_person, :package => params[:package], :role => params[:role]
      return
    end

    user = Person.find( :login => params[:userid] )
    logger.debug "found user: #{user.inspect}"
    
    if not user
      flash[:error] = "Unknown user with id '#{params[:userid]}'"
      redirect_to :action => :add_person, :package => params[:package], :role => params[:role]
      return
    end

    @project_name = session[:project_name]
    @package = Package.find( session[:package], :project => @project_name )
    @package.add_person( :userid => params[:userid], :role => params[:role] )

    if @package.save
      flash[:note] = "added user #{params[:userid]}"
    else
      flash[:note] = "Failed to add user '#{params[:userid]}'"
    end
 
    redirect_to :action => :show, :package => @package, :project => @project_name
  end

  def remove_person
    if not params[:userid]
      flash[:note] = "User removal aborted, no user id given!"
      redirect_to :action => :show, :package => params[:package], :project => params[:project]
      return
    end

    @package = Package.find( params[:package], :project => params[:project] )
    @package.remove_persons( :userid => params[:userid], :role => params[:role] )

    if @package.save
      flash[:note] = "removed user #{params[:userid]}"
    else
      flash[:note] = "Failed to remove user '#{params[:userid]}'"
    end

    redirect_to :action => :show, :package => params[:package], :project => params[:project]
  end
  
  def edit_spec
    @project = params[:project]
    @package = params[:package]
    @filename = params[:file]
    
    @specfile = frontend.get_source( :project => @project,
      :package => @package, :filename => @filename )
  end
  
  def edit_link
    @project = params[:project]
    @package = params[:package]
    @filename = params[:file]
    
    @linkfile = frontend.get_source( :project => @project,
      :package => @package, :filename => @filename )
  end
  
  def save_spec
    project = params[:project]
    package = params[:package]
    specfile = params[:specfile]
    filename = params[:filename]

    if( filename =~ /\.spec$/ )
      specfile.gsub!( /\r\n/, "\n" )
      
      frontend.put_file( specfile, :project => project, :package => package,
        :filename => filename )

      flash[:note] = "Successfully saved SPEC file."
    else
      flash[:note] = "Aborted saving of specfile: suffix not .spec"
    end
    
    redirect_to :action => :show, :package => package, :project => project
  end

  def save_link
    project = params[:project]
    package = params[:package]
    linkfile = params[:linkfile]
    filename = params[:filename]

    if( filename == "_link" )
      linkfile.gsub!( /\r\n/, "\n" )
      
      frontend.put_file( linkfile, :project => project, :package => package,
        :filename => filename )

      flash[:note] = "Successfully saved link file."
    else
      flash[:note] = "Aborted saving of linkfile: filename not '_link'"
    end
    
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
      end

    rescue ActiveXML::Transport::Error => ex
      if ex.message.root.elements['code'].text == "404"
        @log_chunk = "No live log available"
        @finished = true
      else
        raise
      end
    end

    render :partial => 'update_build_log'
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
        
    logger.debug( "Trigger Rebuild for #{package}" )
    frontend.cmd_package( project, package, "rebuild" )
    
    flash[:note] = "Triggered rebuild."
    
    redirect_to :action => "show", :project => project, :package => package
  end

  def check_params

    if params[:package]
      unless valid_package_name?( params[:package] )
        flash[:error] = "Invalid package name, may only contain alphanumeric characters"
        redirect_to :action => :error
      end
    end

    if params[:project]
      unless valid_project_name?( params[:project] )
        flash[:error] = "Invalid project name, may only contain alphanumeric characters"
        redirect_to :action => :error
      end
    end

  end

end
