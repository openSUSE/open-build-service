class AttributesController < ApplicationController
  
  def index
    redirect_to :action => "add_attribute"
  end

  def add_attribute
    @project = Project.find(params[:project]) 
    @package = params[:package]
    given_attribute = params[:attribute]
    if @project
      if given_attribute
        if @package
          attributes = Attributes.find(:project => @project, :package => @package)
        else
          attributes = Attributes.find(:project, :project => @project)
        end
        attributes.each do |a|
          if a.data.attributes["name"].to_s == given_attribute
            @attribute = given_attribute
            @values_split = []
            @values = ""
            if a.has_element? :value
              a.each do |b|
                @values += ","+b.to_s
              end
              @values = @values[1..@values.length]
              @values_split = @values.split(",")
            end
          end 
        end
      else
        @attribute = ""
        @values_split = []
        @values = ""
      end
    else
      flash[:error] = "No project given!"
      redirect_to :controller => "project", :action => "list_public"
    end
  end

  def save_attribute
    project = Project.find(params[:project])
    package = params[:package]
    attribute = params[:attribute]
    if (project.is_maintainer? session[:login]) && attribute 
      data2,data = "",""
      values = params[:values].split(",")
      values.each do |a|
        data2 += "<value>#{a}</value>"
      end
      data = "<attributes><attribute name='#{attribute}'>#{data2}</attribute></attributes>"
      transport ||= ActiveXML::Config::transport_for(:project)
      path = package ? "/source/#{project}/#{package}/_attribute" : "/source/#{project}/_attribute"
      begin
        transport.direct_http URI("https://#{path}"), :method => "POST", :data => data
        flash[:note] = "Attribute sucessfully added!" 
      rescue ActiveXML::Transport::Error
        flash[:error] = "Something went wrong! Maybe the attribute is not allowed." 
      end
      if package
        redirect_to :controller => "package", :action => "show", :project => project, :package => package
      else
        redirect_to :controller => "project", :action => "show", :project => project
      end
 
    else
      flash[:error] = "An error occurred!"
      redirect_to :controller => "project", :action => "list_public"
    end
  end

  def delete_attribute
    project = Project.find(params[:project])
    package = params[:package]
    attribute = params[:attribute]
    if (project.is_maintainer? session[:login]) && attribute
      transport ||= ActiveXML::Config::transport_for(:project)
      path = package ? "/source/#{project}/#{package}/_attribute/#{attribute}" : "/source/#{project}/_attribute/#{attribute}"
      transport.direct_http URI("https://#{path}"), :method => "DELETE", :data => ""
      flash[:note] = "Attribute successfully deleted!"
    end
    if package
      redirect_to :controller => "package", :action => "show", :project => project, :package => package
    else
      redirect_to :controller => "project", :action => "show", :project => project
    end
  end
end
