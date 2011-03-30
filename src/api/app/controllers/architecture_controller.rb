require 'opensuse/validator'

class ArchitectureController < ApplicationController

  validate_action :index => {:method => :get, :response => :directory}
  validate_action :show  => {:method => :get, :response => :architecture}

  # GET /architecture
  def index
    architectures = Architecture.all()
    builder = Builder::XmlMarkup.new(:indent => 2)
    xml = builder.directoryectory(:count => architectures.length) do |directory|
      architectures.each {|arch| directory.entry(:name => arch.name)}
    end
    render :text => xml, :content_type => "text/xml"
  end

  # GET /architecture/:name
  def show
    unless params[:name]
      render_error :status => 400, :errorcode => "missing_parameter'", :message => "Missing parameter 'name'" and return
    end
    architecture = Architecture.find_by_name(params[:name])
    unless architecture
      render_error :status => 400, :errorcode => "unknown_architecture", :message => "Architecture does not exist: #{params[:name]}" and return
    end
    builder = Builder::XmlMarkup.new(:indent => 2)

    xml = builder.architecture(:name => architecture.name) do |arch|
      arch.selectable(architecture.selectable)
      arch.enabled(architecture.enabled)
    end
    render :text => xml, :content_type => "text/xml"
  end

end
