class ConfigurationController < ApplicationController

  before_filter :require_admin
  before_filter :require_available_architectures, :only => [:index, :update_architectures]

  def index
  end

  def connect_instance
  end

  def save_instance
    #store project
    required_parameters :name, :title, :description, :remoteurl

    if params[:name].blank? || !valid_project_name?( params[:name] )
      flash[:error] = "Invalid project name '#{params[:name]}'."
      redirect_to :action => :connect_instance and return
    end

    project_name = params[:name].strip

    if Project.exists? project_name
      flash[:error] = "Project '#{project_name}' already exists."
      redirect_to :action => :connect_instance and return
    end

    @project = Project.new(:name => project_name)
    @project.title.text = params[:title]
    @project.description.text = params[:description]
    @project.set_remoteurl(params[:remoteurl])

    if @project.save
      if Project.exists? "home:#{@user.login.to_s}"
        flash[:note] = "Project '#{project_name}' was created successfully"
        redirect_to :action => 'show', :project => project_name and return
      else
        flash[:note] = "Project '#{project_name}' was created successfully. Next step is create your home project"
        redirect_to :controller => :project, :action => :new, :ns => "home:#{@user.login.to_s}"
      end
    else
      flash[:error] = "Failed to save project '#{@project}'"
    end
  end

  def update_configuration
    valid_http_methods :post
    if ! (params[:title] || params[:target_project])
      flash[:error] = "Missing arguments (title or description)"
      redirect_back_or_to :action => 'index' and return
    end

    begin
      data = "title=#{CGI.escape(params[:title])}%20Open%20Build%20Service&description=#{CGI.escape(params[:description])}"
      response = ActiveXML::Config::transport_for(:configuration).direct_http(URI('/configuration'), :method => 'PUT', :content_type => 'application/x-www-form-urlencoded', :data => data)
      flash[:note] = "Updated configuration"
      Rails.cache.delete('configuration')
    rescue ActiveXML::Transport::Error => e
      logger.debug "Failed to update configuration"
      flash[:error] = "Failed to update configuration"
    end
    redirect_to :action => 'index'
  end

  def update_architectures
    valid_http_methods :post

    @available_architectures.each do |arch_elem|
      arch = Architecture.find_cached(arch_elem.name) # fetch a real 'Architecture' from 'directory' entry
      if params[:arch_recommended] and params[:arch_recommended].include?(arch.name) and arch.recommended.text == 'false'
        arch.recommended.text = 'true'
        arch.save
        Architecture.free_cache(:available)
      elsif arch.recommended.text == 'true'
        arch.recommended.text = 'false'
        arch.save
        Architecture.free_cache(:available)
      end
    end
    redirect_to :action => 'index'
  end

end
