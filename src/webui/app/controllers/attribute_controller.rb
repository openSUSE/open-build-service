class AttributeController < ApplicationController

  before_filter :requires

  def edit
    all_attributes = Attribute.find(:all, :namespace => "OBS")
    @attribute_list = []  
    return unless all_attributes
    all_attributes.each_entry do |d|
      @attribute_list << "OBS:#{d.name}"
    end
    @attributes.each do |d|
      @attribute_list.delete(d.name)
    end
    @selected_attribute = params[:attribute]
  end

  def save
    values = params[:values].split(',')
    @attributes.set("OBS", params[:attribute], values)
    result = @attributes.save
    opt = {:controller => "attribute", :action => "show", :project => @project.name }
    opt.store( :package, params[:package] ) if params[:package]
    flash[result[:type]] = result[:msg]
    redirect_to opt
  end

  def delete
    result = @attributes.delete(params[:attribute])
    flash[result[:type]] = result[:msg]
    opt = {:controller => "attribute", :action => "show", :project => @project.name }
    opt.store( :package, params[:package] ) if params[:package]
    redirect_to opt
  end

private

  def requires
    begin
      @project = Project.find( params[:project] )
      if (params[:package])
        @attributes = Attribute.find(:project => params[:project], :package => params[:package])
      else
        @attributes = Attribute.find(:project, :project => params[:project])
      end
    rescue Error => e
      flash[:error] = "Attributes not found: #{e.message}"
      redirect_to :controller => "project", :action => "list_public" and return
    end
  end

end
