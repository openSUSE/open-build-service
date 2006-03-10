class PackageController < ApplicationController
  model :project, :package, :result
  before_filter :check_params
  
  def show
    #FIXME: breaks if one of the params is not set
    @project = Project.find( params[:project] )
    @package = Package.find( params[:name], :project => params[:project])

    session[:project_name] = params[:project]
    
    @results = []
    @project.each_repository do |repository|
      result = Result.find( :project => params[:project], :package => params[:name], :platform => repository.name )
      @results << result if result
    end

  end

  def new
    if not params[:project]
      flash[:note] = "Creating package failed: Project name missing"
      redirect_to :controller => "project", :action => "list_all"
      return
    end
    
    @project = Project.find( params[:project] )

    if params[:name]
      @package = Package.new( :name => params[:name], :project => @project )

      @package.title.data.text = params[:title]
      @package.description.data.text = params[:description]
      if params[:createSpecFileTemplate]
        @package.add_file :filename => params[:name] + ".spec"
      end

      @project.add_package @package

      if @project.save and @package.save
        if params[:createSpecFileTemplate]
          logger.debug( "CREATE SPEC FILE TEMPLATE" )
          frontend.cmd_package( @project.name, @package.name,
            "createSpecFileTemplate" )
        end
      
        flash[:note] = "Package '#{@package}' was created successfully"
        redirect_to :action => 'show', :project => params[:project], :name => params[:name]
      else
        flash[:note] = "Failed to save package '#{@package}'"
        redirect_to :controller => 'project', :action => 'show', :name => params[:project]
      end
    else
      #show template
    end
  end

  def edit
    @project = Project.find( params[:project] )
    @package = Package.find( params[:name], :project => params[:project] )
  end

  def save
    @package = Package.find( params[:name], :project => params[:project] )

    @package.title.data.text = params[:title]
    @package.description.data.text = params[:description]

    if @package.save
      flash[:note] = "Package '#{@package.name}' was saved successfully"
    else
      flash[:note] = "Failed to save package '#{@package.name}'"
    end
    redirect_to :action => 'show', :project => params[:project], :name => params[:name]
  end

  def remove
    @project = Project.find( params[:project] )
    @package_name = params[:name]

    @project.remove_package @package_name
    
    if @project.save
      flash[:note] = "Package '#{@package_name}' was removed successfully from project '#{@project}'"
    else
      flash[:note] = "Failed to remove package '#{@package_name}' from project '#{@project}'"
    end
    redirect_to :controller => 'project', :action => :show, :name => params[:project]
  end

  def add_file
    @project = Project.find( params[:project] )
    @package = Package.find( params[:name], :project => params[:project] )
    session[:project] = @project.name
    session[:package] = @package.name
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
    filetype = params[:filetype]

    logger.debug "controller: starting to add file: #{filename}"
    @package.add_file :file => file, :filename => filename, :filetype => filetype

    if @package.save_files and @package.save
      flash[:note] = "File '#{filename}' added successfully"
    else
      flash[:note] = "Failed to add file '#{filename}'"
    end

    redirect_to :action => :show, :project => @project, :name => @package
  end

  def add_person
    @project_name = session[:project_name]
    @package = Package.find( params[:name], :project => @project_name )
    session[:package] = @package.name
  end

  def save_person
    if not params[:userid]
      flash[:error] = "Login missing"
      redirect_to :action => :add_person, :name => params[:name], :role => params[:role]
      return
    end

    user = Person.find( :login => params[:userid] )
    logger.debug "found user: #{user.inspect}"
    
    if not user
      flash[:error] = "Unknown user with id '#{params[:userid]}'"
      redirect_to :action => :add_person, :name => params[:name], :role => params[:role]
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
    response = Suse::Backend.get_log( @project, @repository, @package, @arch )
    send_data( response.body, :type => "text/plain",
      :disposition => "inline" )
 
    redirect_to :action => :show, :name => @package, :project => @project_name
  end

  def remove_person
    if not params[:userid]
      flash[:note] = "User removal aborted, no user id given!"
      redirect_to :action => :show, :name => params[:name], :project => params[:project]
      return
    end

    @package = Package.find( params[:name], :project => params[:project] )
    @package.remove_persons( :userid => params[:userid], :role => params[:role] )

    if @package.save
      flash[:note] = "removed user #{params[:userid]}"
    else
      flash[:note] = "Failed to remove user '#{params[:userid]}'"
    end

    redirect_to :action => :show, :name => params[:name], :project => params[:project]
  end
  
  def edit_spec
    @project = params[:project]
    @package = params[:package]
    
    @specfile = frontend.get_source( :project => @project,
      :package => @package, :filename => @package + ".spec" )
  end
  
  def save_spec
    project = params[:project]
    package = params[:package]
    specfile = params[:specfile]

    specfile.gsub!( /\r\n/, "\n" )
    
    frontend.put_file( specfile, :project => project, :package => package,
      :filename => package + ".spec" )

    flash[:note] = "Successfully saved SPEC file."
    
    redirect_to :action => :show, :name => package, :project => project
  end

  def live_build_log
    @project = params[:project]
    @package = params[:name]
    @arch = params[:arch]
    @repo = params[:repository]

    begin
      @log_chunk = TRANSPORT.get_log_chunk( @project, @package, @repo, @arch )
      @offset = @log_chunk.length
    rescue Suse::Frontend::UnspecifiedError => ex
      if ex.message.root.elements['code'].text == "404"
        @log_chunk = "No live log available"
      else
        raise
      end
    end
  end

  def update_build_log
    @project = params[:project]
    @package = params[:name]
    @arch = params[:arch]
    @repo = params[:repository]
    @offset = params[:offset].to_i

    begin
      @log_chunk = TRANSPORT.get_log_chunk( @project, @package, @repo, @arch, @offset )
      
      if( @log_chunk.length == 0 )
        @finished = true
      else
        @offset += @log_chunk.length
      end

    rescue Suse::Frontend::UnspecifiedError => ex
      if ex.message.root.elements['code'].text == "404"
        @log_chunk = "No live log available"
        @finished = true
      else
        raise
      end
    end

    render :partial => 'update_build_log'
  end

  def check_params
    logger.debug "Checking parameter #{params[:name]}"
    if params[:name]
      unless params[:name] =~ /^\w[-\w]*$/
        flash[:error] = "Invalid package name, may only contain alphanumeric characters"
        redirect_to :action => :error
      end
    end

    if params[:project]
      unless params[:project] =~ /^\w[-\w]*$/
        flash[:error] = "Invalid project name, may only contain alphanumeric characters"
        redirect_to :action => :error
      end
    end

    if params[:package]
      unless params[:package] =~ /^\wi[-\w]*$/
        flash[:error] = "Invalid package name, may only contain alphanumeric characters"
        redirect_to :action => :error
      end
    end

  end

 
end
