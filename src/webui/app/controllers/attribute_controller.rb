class AttributeController < ApplicationController

  helper :all

  before_filter :requires

  def edit
    if @attributes.nil? # fails if package does not exist in project anymore
      redirect_to :controller => :project, :action => :attributes, :project => params[:project]
      return
    end
    if params[:namespace] and params[:name]
      selected_attribute = @attributes.data.find_first( "attribute[@name='#{params[:name]}' and @namespace='#{params[:namespace]}']")
      @selected_attribute_name =  "%s:%s" % [params[:namespace], params[:name]]
      @selected_attribute_value = selected_attribute.find("value").map{|value| value.content.strip}.join(', ') if selected_attribute
    else
      namespaces = find_cached(Attribute, :namespaces)
      attributes = []
      @attribute_list = []
      namespaces.each do |d|
         attributes << find_cached(Attribute, :attributes, :namespace => d.data[:name].to_s, :expires_in => 10.minutes)
      end
      attributes.each do |d|
        if d.has_element? :entry
          d.each do |f|
            @attribute_list << "#{d.init_options[:namespace]}:#{f.data[:name]}"
          end
        end
      end
      @attributes.each do |d|
        @attribute_list.delete(d.name)  
      end
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
      redirect_to :controller => "project", :action => "list_public"
      return
    end
    @package = params[:package] if params[:package]
    @attribute_opts = {:project => @project.name}
    @attribute_opts.store(:package, @package.to_s) if @package
    @attributes = find_cached(Attribute, @attribute_opts, :expires_in => 2.minutes)
  end

end
