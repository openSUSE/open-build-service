class AttributeController < ApplicationController
  helper :all
  before_filter :requires

  def edit
    if @attributes.nil? # fails if package does not exist in project anymore
      redirect_to :controller => :project, :action => :attributes, :project => params[:project] and return
    end
    if params[:namespace] and params[:name]
      selected_attribute = nil
      selected_attribute = @attributes.find_first( "attribute[@name='#{params[:name]}' and @namespace='#{params[:namespace]}']")
      @selected_attribute_name =  "%s:%s" % [params[:namespace], params[:name]]
      @selected_attribute_value = Array.new
      selected_attribute.each("value") {|value| @selected_attribute_value << value.text} if selected_attribute
      @selected_attribute_value = @selected_attribute_value.join(', ')
    else
      namespaces = find_cached(Attribute, :namespaces)
      attributes = []
      @attribute_list = []
      namespaces.each do |d|
         attributes << find_cached(Attribute, :attributes, :namespace => d.value(:name), :expires_in => 10.minutes)
      end
      attributes.each do |d|
        if d.has_element? :entry
          d.each {|f| @attribute_list << "#{d.init_options[:namespace]}:#{f.value(:name)}" }
        end
      end
      @attributes.each {|d| @attribute_list.delete(d.name)}
    end
  end

  def save
    valid_http_methods(:post)
    values = params[:values].split(',')
    namespace, name = params[:attribute].split(/:/)
    @attributes.set(namespace, name, values)
    result = @attributes.save
    Attribute.free_cache( @attribute_opts )
    if params[:package]
      opt = {:controller => :package, :action => :attributes, :project => @project.name }
    elsif params[:project]
      opt = {:controller => :project, :action => :attributes, :project => @project.name }
    end
    opt.store( :package, params[:package] ) if params[:package]
    flash[result[:type]] = result[:msg]
    redirect_to opt
  end

  def delete
    valid_http_methods(:post, :delete)
    result = @attributes.delete(params[:namespace], params[:name])
    flash[result[:type]] = result[:msg]
    Attribute.free_cache( @attribute_opts )
    if params[:package]
      opt = {:controller => :package, :action => :attributes, :project => @project.name }
    elsif params[:project]
      opt = {:controller => :project, :action => :attributes, :project => @project.name }
    end
    opt.store( :package, params[:package] ) if params[:package]
    redirect_to opt
  end

private

  def requires
    @project = find_cached(Project, params[:project], :expires_in => 5.minutes )
    unless @project
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public" and return
    end
    @is_maintenance_project = false
    @is_maintenance_project = true if @project.project_type and @project.project_type == "maintenance"
    @package = find_cached(Package, params[:package], :project => @project.name) if params[:package]
    @attribute_opts = {:project => @project.name}
    @attribute_opts.store(:package, @package.to_s) if @package
    @attributes = find_cached(Attribute, @attribute_opts, :expires_in => 2.minutes)
  end
end
