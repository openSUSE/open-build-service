class AttributeController < ApplicationController

  before_filter :requires

  def index
  end

  def show
  end  


  def edit
    all_attributes = Attribute.find(:all, :namespace => "OBS")
    @attribute_list = []  
    unless all_attributes
      return 
    end
    all_attributes.attributes.each_definition do |d|
      @attribute_list << "#{d.namespace}:#{d.name}"
    end
   
    @attribute.each do |d|
      @attribute_list.delete(d.name)  
    end
     
    @selected_attribute = params[:attribute] if params[:attribute]
    
  end

  def save
    values = params[:values].split(',')
     
    @attribute.set(params[:attribute], values)
    result = @attribute.save
    
    opt = {:controller => "attribute", :action => "show", :project => @project.name }
    opt.store( :package, params[:package] ) if params[:package]
    
    flash[result[:type]] = result[:msg]
    redirect_to opt
  end

  def delete
    result = @attribute.delete(params[:attribute])
    flash[result[:type]] = result[:msg]

    opt = {:controller => "attribute", :action => "show", :project => @project.name }
    opt.store( :package, params[:package] ) if params[:package]

    redirect_to opt
  end

private

  def requires
    begin
      @project = Project.find( params[:project] )
      @package = params[:package] if params[:package]
      opt = {:project => @project.name}
      opt.store(:package, @package.to_s) if @package
      @attribute = Attribute.find(opt)
    rescue ActiveXML::Transport::NotFoundError => e
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public"
      return
    end
  end

end
