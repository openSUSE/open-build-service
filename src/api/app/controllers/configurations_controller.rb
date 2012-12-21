require 'configuration'

class ConfigurationsController < ApplicationController
  # Site-specific configuration is insensitive information, no login needed therefore
  skip_before_filter :extract_user, :only => [:show]
  before_filter :require_admin, :only => [:update]

  validate_action :show => {:method => :get, :response => :configuration}
# webui is using this route with parameters instead of content
#  validate_action :update => {:method => :put, :request => :configuration}

  # GET /configuration
  # GET /configuration.json
  # GET /configuration.xml
  def show
    @configuration = ::Configuration.select("title, description").first

    respond_to do |format|
      format.xml  { render :xml => @configuration }
      format.json { render :json => @configuration }
    end
  end

  # PUT /configuration
  # PUT /configuration.json
  # PUT /configuration.xml
  def update
    @configuration = ::Configuration.first

    respond_to do |format|
      xml = params["xmlhash"] || {}
      attribs = {}
      attribs[:title] = xml["title"] || params["title"]
      attribs[:description] = xml["description"] || params["description"]
      ret = @configuration.update_attributes(attribs)
      if ret
        format.xml  { head :ok }
        format.json { head :ok }
      else
        format.xml  { render :xml => @configuration.errors, :status => :unprocessable_entity }
        format.json { render :json => @configuration.errors, :status => :unprocessable_entity }
      end
    end
  end
end
