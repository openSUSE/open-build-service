class AttributesController < ApplicationController

  before_filter :require_project

  def add_attribute
    @package = params[:package]
    if( attribute_name = params[:attribute] )
      if @package
        attribute = Attributes.find(:project => @project, :package => @package, :attribute => attribute_name)
      else
        attribute = Attributes.find(:project, :project => @project, :attribute => attribute_name)
      end
    end
    @attribute = attribute.attribute  if attribute && (attribute.has_element? 'attribute')
  end

  def save_attribute
    valid_http_methods :post
    package = params[:package]
    attribute = params[:attribute]
    data2,data = "",""
    values = params[:values].split(",")
    values.each do |a|
      data2 += "<value>#{a.strip}</value>"
    end
    data = "<attributes><attribute name='#{attribute}'>#{data2}</attribute></attributes>"
    path = package ? "/source/#{@project}/#{package}/_attribute" : "/source/#{@project}/_attribute"
    begin
      frontend.transport.direct_http URI("#{path}"), :method => "POST", :data => data
      flash[:success] = "Attribute sucessfully added!"
    rescue ActiveXML::Transport::Error => e
      flash[:error] = "Saving attribute failed: #{ActiveXML::Transport.extract_error_message( e )[0]}"
      redirect_to :action => :add_attribute, :project => @project,
        :package => package, :attribute => attribute and return
    end
    if package
      redirect_to :controller => "package", :action => "show", :project => @project, :package => package
    else
      redirect_to :controller => "project", :action => "show", :project => @project
    end
  end

  def delete_attribute
    package = params[:package]
    attribute = params[:attribute]
    if (@project.is_maintainer? session[:login]) && attribute
      transport ||= ActiveXML::Config::transport_for(:project)
      path = package ? "/source/#{@project}/#{package}/_attribute/#{attribute}" : "/source/#{@project}/_attribute/#{attribute}"
      transport.direct_http URI("https://#{path}"), :method => "DELETE", :data => ""
      flash[:note] = "Attribute successfully deleted!"
    end
    if package
      redirect_to :controller => "package", :action => "show", :project => @project, :package => package
    else
      redirect_to :controller => "project", :action => "show", :project => @project
    end
  end

private

  def require_project
    begin
      @project = Project.find( params[:project] )
    rescue ActiveXML::Transport::NotFoundError => e
      flash[:error] = "Project not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public"
      return
    end
  end

end