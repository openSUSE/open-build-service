require 'opensuse/validator'

class ArchitecturesController < ApplicationController

  validate_action :index => {:method => :get, :response => :directory}
  validate_action :show  => {:method => :get, :response => :architecture}

  before_filter :update_architecture_state, :only => [:index, :show]
  before_filter :require_admin, :only => [:create, :update, :delete]

  # GET /architecture
  # GET /architecture.xml
  def index
    @architectures = Architecture.all()

    respond_to do |format|
      format.xml do 
        builder = Builder::XmlMarkup.new(:indent => 2)
        arch_count = 0
        xml = builder.directory(:count => '@@@') do |directory|
          @architectures.each do |arch|
            # Check for 'recommended' or 'available' filters
            next unless arch.recommended if ["1", "true"].include?(params[:recommended])
            next if arch.recommended if ["0", "false"].include?(params[:recommended])
            next unless arch.available if ["1", "true"].include?(params[:available])
            next if arch.available if ["0", "false"].include?(params[:available])
            # Add directory entry that survived filtering
            directory.entry(:name => arch.name, :available => arch.available, :recommended => arch.recommended)
            arch_count += 1
          end
        end
        # Builder::XML doesn't allow setting attributes later on, thus the usage of a placeholder
        xml.gsub!(/@@@/, arch_count.to_s)
        render :xml => xml
      end
    end
  end

  # GET /architecture/i386
  # GET /architecture/i386.xml
  def show
    required_parameters :id
    @architecture = Architecture.find_by_name(params[:id])
    unless @architecture
      render_error :status => 400, :errorcode => "unknown_architecture", :message => "Architecture does not exist: #{params[:id]}" and return
    end

    respond_to do |format|
      format.xml do
        builder = Builder::XmlMarkup.new(:indent => 2)
        xml = builder.architecture(:name => @architecture.name) do |arch|
          arch.available(@architecture.available)
          arch.recommended(@architecture.recommended)
        end
        render :xml => xml
      end
    end
  end

  # POST /architecture/i386
  def create
    required_parameters :id

    xml = REXML::Document.new(request.raw_post)
    @architecture = Architecture.new(
      :name => xml.elements["/architecture/@name"].value,
      :recommended => xml.elements["/architecture/recommended"].text,
      :available => xml.elements["/architecture/available"].text
    )

    respond_to do |format|
      if @architecture.save
        format.xml { render :xml => @architecture, :status => :created, :location => @architecture }
      else
        format.xml { render :xml => @architecture.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /architecture/i385
  def update
    required_parameters :id
    @architecture = Architecture.find_by_name(params[:id])
    unless @architecture
      render_error :status => 400, :errorcode => "unknown_architecture", :message => "Architecture does not exist: #{params[:id]}" and return
    end

    xml = REXML::Document.new(request.raw_post)
    respond_to do |format|
      if @architecture.update_attributes(:recommended => xml.elements["/architecture/recommended"].text,
                                         :available => xml.elements["/architecture/available"].text)
        format.xml { head :ok }
      else
        format.xml { render :xml => @architecture.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /architecture/i386
  def delete
    required_parameters :id
    @architecture = Architecture.find_by_name(params[:id])
    @architecture.destroy

    respond_to do |format|
      format.xml { head :ok }
    end
  end

private
  # Architecture availability is dependant on scheduler state. Therefore, the table is
  # periodically updated to reflect the scheduler states. A cache key serves as the timer.
  def update_architecture_state
    Rails.cache.fetch("architecture_backend_state", :expires_in => 5.minutes, :shared => true) do
      logger.debug "Updating architecture availability from backend..."

      raw = backend_get("/build/_workerstatus")
      data = REXML::Document.new(raw) # Parse backend XML
      data.root.each_element("partition") do |partition|
        partition.each_element("daemon") do |daemon|
          next unless daemon.attributes["type"] == "scheduler"
          arch_name = daemon.attributes["arch"]

          # Update availability based on scheduler state for given arch
          @architecture = Architecture.find_by_name(arch_name)
          if @architecture
            @architecture.available = ["idle", "running"].include? daemon.attributes["state"]
            @architecture.save!
          else
            # The backend supports an architecture that the API table doesn't know about (i.e. not part of the default
            # set of architectures). Add it as another available architecture but don't recommend it by default.
            @architecture = Architecture.create(:name => arch_name, :recommended => false, :available => daemon.attributes["state"])
          end
        end
      end
    end
  end

end
