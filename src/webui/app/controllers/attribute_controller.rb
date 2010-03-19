class AttributeController < ApplicationController

  before_filter :requires

  def edit
    if params[:namespace] and params[:name]
      selected_attribute = @attributes.data.find_first( "attribute[@name='#{params[:name]}' and @namespace='#{params[:namespace]}']/value")
      if selected_attribute
        @selected_attribute_name =  "%s:%s" % [params[:namespace], params[:name]]
        @selected_attribute_value = selected_attribute.content
      end
    else
      namespaces = Attribute.find(:namespaces)
      attributes = []
      @attribute_list = []
      namespaces.each do |d|
         attributes << Attribute.find(:attributes, :namespace => d.data[:name].to_s)
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
    values = params[:values].split(',')
    namespace, name = params[:attribute].split(/:/)
    @attributes.set(namespace, name, values)
    result = @attributes.save
    opt = {:controller => "attribute", :action => "show", :project => @project.name }
    opt.store( :package, params[:package] ) if params[:package]
    flash[result[:type]] = result[:msg]
    redirect_to opt
  end

  def delete
    result = @attributes.delete(params[:namespace], params[:name])
    flash[result[:type]] = result[:msg]
    opt = {:controller => "attribute", :action => "show", :project => @project.name }
    opt.store( :package, params[:package] ) if params[:package]
    redirect_to opt
  end

private

  def requires
    @project = Project.find( params[:project] )
    unless @project
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public"
      return
    end
    @package = params[:package] if params[:package]
    opt = {:project => @project.name}
    opt.store(:package, @package.to_s) if @package
    @attributes = Attribute.find(opt)
  end

end
