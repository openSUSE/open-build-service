require 'configuration'

class ConfigurationsController < ApplicationController
  # Site-specific configuration is insensitive information, no login needed therefore
  skip_before_filter :extract_user, :only => [:show]
  before_filter :require_admin, :only => [:update]
  skip_filter :validate_params, :only => [:update] # we use an array for archs here

  validate_action :show => {:method => :get, :response => :configuration}
# webui is using this route with parameters instead of content
#  validate_action :update => {:method => :put, :request => :configuration}

  # GET /configuration
  # GET /configuration.json
  # GET /configuration.xml
  def show
    @configuration = ::Configuration.select("title, description, name").first
    @architectures = Architecture.where(:available => 1)

    respond_to do |format|
      format.xml  
      format.json { render :json => @configuration }
    end
  end

  # PUT /configuration
  # PUT /configuration.json
  # PUT /configuration.xml
  def update
    @configuration = ::Configuration.first

    respond_to do |format|
      xml = Xmlhash.parse(request.raw_post) || {}
      attribs = {}
      # scheduler architecture list
      archs=nil
      if xml["schedulers"] and xml["schedulers"]["arch"].class == Array
        archs=Hash[xml["schedulers"]["arch"].map{|a| [a, 1]}]
      end
      if params["arch"].class == Array
        archs=Hash[params["arch"].map{|a| [a, 1]}]
      end
      if archs
        Architecture.all().each do |arch|
          if arch.available != (archs[arch.name] == 1)
            arch.available = (archs[arch.name] == 1)
            arch.save!
          end
        end
      end

      # standard values
      attribs[:title] = xml["title"] || params["title"].to_s
      attribs[:description] = xml["description"] || params["description"].to_s
      attribs[:name] = xml["name"] || params["name"].to_s
      attribs.keys.each do |k|
        attribs.delete(k) if attribs[k].blank?
      end
      ret = @configuration.update_attributes(attribs)
      if ret
        @configuration.save!
        format.xml  { head :ok }
        format.json { head :ok }
      else
        format.xml  { render :xml => @configuration.errors, :status => :unprocessable_entity }
        format.json { render :json => @configuration.errors, :status => :unprocessable_entity }
      end
    end
  end
end
