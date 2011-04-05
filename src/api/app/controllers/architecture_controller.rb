require 'opensuse/validator'

class ArchitectureController < ApplicationController

  validate_action :index => {:method => :get, :response => :directory}
  validate_action :show  => {:method => :get, :response => :architecture}

  # GET /architecture
  def index
    architectures = Architecture.all()
    builder = Builder::XmlMarkup.new(:indent => 2)
    xml = builder.directory(:count => architectures.length) do |directory|
      architectures.each do |arch|
        directory.entry(:name => arch.name, :available => arch.available, :recommended => arch.recommended)
      end
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
      arch.available(architecture.available)
      arch.recommended(architecture.recommended)
    end
    render :text => xml, :content_type => "text/xml"
  end

  # POST /architecture/:name
  def create
    unless @http_user.is_admin?
      render_error :status => 403, :errorcode => "put_request_no_permission", :message => "PUT on requests currently requires admin privileges" and return
    end
    unless params[:name]
      render_error :status => 400, :errorcode => "missing_parameter'", :message => "Missing parameter 'name'" and return
    end

    xml = REXML::Document.new(request.raw_post)
    architecture = Architecture.new(
      :name => xml.elements["/architecture/@name"].value,
      :recommended => xml.elements["/architecture/recommended"].text,
      :available => xml.elements["/architecture/available"].text
    )
    architecture.save!
    render_ok
  end

  # PUT /architecture/:name
  def update
    unless @http_user.is_admin?
      render_error :status => 403, :errorcode => "put_request_no_permission", :message => "PUT on requests currently requires admin privileges" and return
    end
    unless params[:name]
      render_error :status => 400, :errorcode => "missing_parameter'", :message => "Missing parameter 'name'" and return
    end
    architecture = Architecture.find_by_name(params[:name])
    unless architecture
      render_error :status => 400, :errorcode => "unknown_architecture", :message => "Architecture does not exist: #{params[:name]}" and return
    end

    xml = REXML::Document.new(request.raw_post)
    logger.debug("XML: #{request.raw_post}")
    #architecture.name = xml.elements["/architecture/@name"].text # We don't want this!
    architecture.recommended = xml.elements["/architecture/recommended"].text
    architecture.available = xml.elements["/architecture/available"].text
    architecture.save!
    render_ok
  end

  # DELETE /architecture/:name
  def delete
    unless @http_user.is_admin?
      render_error :status => 403, :errorcode => "put_request_no_permission", :message => "PUT on requests currently requires admin privileges" and return
    end
    unless params[:name]
      render_error :status => 400, :errorcode => "missing_parameter'", :message => "Missing parameter 'name'" and return
    end
    architecture = Architecture.find_by_name(params[:name])
    architecture.destroy
    render_ok
  end

end
