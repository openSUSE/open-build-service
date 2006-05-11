class PlatformController < ApplicationController
  model :platform

  def list_all
    @platforms = Platform.find( :all ).each_entry

    logger.debug( "PLATFORMS: #{@platforms}" )
  end

  def show
    name = params[:name]
    @project = params[:project]
  
    if !name || !@project
      redirect_to :action => :list_all
    else
      @platform = Platform.find( params[:name], :project => @project )
    end
  end

  def new
    @projects = Project.find( :all ).each_entry
  end

  def edit
    if !params[:name] || !params[:project]
      redirect_to :action => :list_all
    else
      @platform = Platform.find( params[:name], :project => params[:project] )
      session[:platform] = @platform
    end
  end

  def save
    @platform = session[:platform]
    project = params[:project]

    if !@platform
      flash[:error] = "Unknown platform"
      redirect_to :action => 'edit', :name => params[:name]
      return
    end

    if ( !params[:title] )
      flash[:error] = "Title must not be empty"
      redirect_to :action => 'edit', :name => params[:name]
      return
    end

    @platform.set_project project
    @platform.title.data.text = params[:title]
    @platform.description.data.text = params[:description]

    logger.debug( "PLATFORM: #{@platform}" )

    if @platform.save
      flash[:note] = "Platform '#{@platform}' was saved successfully"
    else
      flash[:note] = "Failed to save platform '#{@platform}'"
    end
    session[:platform] = nil

    logger.debug( "REDIRECT TO: #{project},#{@platform}" )

    redirect_to( :action => 'show', :name => @platform.to_s,
      :project => project )
  end

  def create
    if !params[:project]
      flash[:error] = "Missing Project"
      redirect_to :action => 'new'
      return
    end
    if !params[:name]
      flash[:error] = "Platform needs a name"
      redirect_to :action => 'edit', :name => params[:name]
      return
    end
    if !params[:title]
      flash[:error] = "Platform needs a title"
      redirect_to :action => 'edit', :name => params[:name]
      return
    end
    
    @platform = Platform.new( :name => params[:name] )

    @platform.set_project params[:project]
    @platform.title.data.text = params[:title]
    @platform.description.data.text = params[:description]

    if @platform.save
      flash[:note] = "Platform '#{@platform}' was created successfully"
    else
      flash[:note] = "Failed to save platform '#{@platform}'"
    end

    redirect_to :action => 'show', :name => params[:name]
  end

end
