class Webui::ConfigurationController < Webui::WebuiController

  include Webui::WebuiHelper
  include Webui::NotificationSettings

  before_filter :require_admin
  before_filter :require_available_architectures, :only => [:index, :update_architectures]

  def index
  end

  def connect_instance
  end

  def users
    @users = ::User.where("login != '_nobody_'").to_a
  end
  
  def groups
    @groups = ::Group.all.to_a
  end

  def save_instance
    #store project
    required_parameters :name, :title, :description, :remoteurl

    if params[:name].blank? || !valid_project_name?( params[:name] )
      flash[:error] = "Invalid project name '#{params[:name]}'."
      redirect_to :action => :connect_instance and return
    end

    project_name = params[:name].strip

    if Project.exists_by_name project_name
      flash[:error] = "Project '#{project_name}' already exists."
      redirect_to :action => :connect_instance and return
    end

    @project = Project.new(name: project_name)
    @project.title = params[:title]
    @project.description = params[:description]
    @project.remoteurl = params[:remoteurl]

    if @project.store
      flash[:notice] = "Project '#{project_name}' was created successfully"
      logger.debug "New remote project with url #{@project.remoteurl}"
      redirect_to :controller => :project, :action => 'show', :project => project_name and return
    else
      flash.now[:error] = "Failed to save project '#{@project}'"
    end
  end

  def update_configuration
    if ! (params[:name]  || params[:title] || params[:description])
      flash[:error] = 'Missing arguments (name, title or description)'
      redirect_back_or_to :action => 'index' and return
    end

    begin
      archs = params[:archs] || []
      archs.each do |archname, value|
        available = value == '1'
        if old = Architecture.where(name: archname, available: !available).first
          old.available = available
          old.save
        end
      end
      c = ::Configuration.first
      c.title = params[:title]
      c.description = params[:description]
      c.name = params[:name]
      c.save
      flash[:notice] = 'Updated configuration'
      Rails.cache.delete('configuration')
    rescue ActiveXML::Transport::Error 
      logger.debug 'Failed to update configuration'
      flash[:error] = 'Failed to update configuration'
    end
    redirect_to :action => 'index'
  end

  def update_architectures
    @available_architectures.each do |arch_elem|
      arch = Architecture.find_by_name(arch_elem.name) # fetch a real 'Architecture' from 'directory' entry
      if params[:arch_available] and params[:arch_available].include?(arch.name) and !arch.available
        arch.available = true
        arch.save
      elsif arch.available
        arch.available = false
        arch.save
      end
    end
    redirect_to :action => 'index'
  end

  def notifications
    notifications_for_user(nil)
  end

  def update_notifications
    update_notifications_for_user(nil)

    flash[:notice] = 'Notifications settings updated'
    redirect_to action: :notifications
  end
end
