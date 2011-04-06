require 'opensuse/validator'

class ArchitectureController < ApplicationController

  validate_action :index => {:method => :get, :response => :directory}
  validate_action :show  => {:method => :get, :response => :architecture}

  before_filter :update_architecture_state, :only => [:index, :show]

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

private
  # Architecture availability is dependant on scheduler state. Therefore, the table is
  # periodically updated to reflect the scheduler states. A cache key serves as the timer.
  def update_architecture_state
    Rails.cache.fetch("architecture_backend_state", :expires_in => 5.minutes, :shared => true) do
      logger.debug "Updating architecture availability from backend..."

      raw = backend_get("/build/_workerstatus")
      data = REXML::Document.new(raw) # Parse backend XML
      data.root.each_element("scheduler") do |scheduler|
        arch_name = scheduler.attributes["arch"]
        # We don't care for backend magic architecture values
        next if ["local", "dispatcher", "publisher", "signer", "warden"].include? arch_name

        # Update availability based on scheduler state for given arch
        architecture = Architecture.find_by_name(arch_name)
        architecture.available = ["idle", "running"].include? scheduler.attributes["state"]
        architecture.save!
      end
    end
  end

end
