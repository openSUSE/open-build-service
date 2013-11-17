class Webui::AttributeController < Webui::WebuiController
  helper :all
  before_filter :requires

  helper 'webui/project'

  def edit
    if @attributes.nil? # fails if package does not exist in project anymore
      redirect_to :controller => :project, :action => :attributes, :project => params[:project] and return
    end
    if params[:namespace] and params[:name]
      selected_attribute = nil
      atype = AttribType.find_by_namespace_and_name(params[:namespace], params[:name])
      selected_attribute = @attributes.where(attrib_type: atype).first
      unless selected_attribute
        redirect_to :back and return
      end
      @selected_attribute_name = '%s:%s' % [params[:namespace], params[:name]]
      @selected_attribute_value = selected_attribute.values 
    else
      @attribute_list = []
      AttribType.all.each do |d|
        @attribute_list << "#{d.attrib_namespace.name}:#{d.name}"
      end
      @attribute_list.sort!
    end
  end

  def save
    values = params[:values].split(',')
    namespace, name = params[:attribute].split(/:/)

    opt = { :action => :edit, :project => @project.name, package: params[:package] }

    unless User.current.can_create_attribute_in? @attribute_container, namespace: namespace, name: name
      redirect_to opt, error: 'No permission to save attribute'
      return
    end

    begin
      Attrib.transaction do
        @attribute_container.store_attribute(namespace, name, values, [])
        @attribute_container.write_attributes # save to backend
      end
    rescue APIException => e
      redirect_to opt, error: "Saving attribute failed: #{e.message}"
      return
    end

    if params[:package]
      opt = {:controller => :package, :action => :attributes, :project => @project.name, package: params[:package] }
    elsif params[:project]
      opt = {:controller => :project, :action => :attributes, :project => @project.name }
    end

    redirect_to opt, notice: 'Attribute sucessfully added!'
  end

  def delete
    required_parameters :namespace, :name

    if params[:package]
      opt = { :controller => :package, :action => :attributes, :project => @project.name, package: params[:package] }
    elsif params[:project]
      opt = { :controller => :project, :action => :attributes, :project => @project.name }
    end

    unless User.current.can_create_attribute_in? @attribute_container, namespace: params[:namespace], name: params[:name]
      redirect_to opt, error: 'Deleting attribute failed: no permission to change attribute'
      return
    end

    atype = AttribType.find_by_namespace_and_name(params[:namespace], params[:name]) 
    @attributes.where(attrib_type: atype).destroy_all
    redirect_to opt, notice: 'Attribute sucessfully deleted!'
  end

  private

  def requires
    required_parameters :project
    @project = WebuiProject.find(params[:project])
    unless @project
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => 'project', :action => 'list_public' and return
    end
    if @project.is_remote?
      flash[:error] = 'Attribute access to remote project is not yet supported'
      if params[:package].blank?
        redirect_to controller: :project, action: :show, project: params[:project]
      else
        redirect_to controller: :package, action: :show, project: params[:project], package: params[:package]
      end
      return
    end
    @is_maintenance_project = false
    @is_maintenance_project = true if @project.project_type and @project.project_type == 'maintenance'
    if params[:package]
      @package = @project.api_obj.find_package(params[:package])
      @attribute_container = @package
    else
      @attribute_container = @project.api_obj
    end
    @attributes = @attribute_container.attribs
  end
end
