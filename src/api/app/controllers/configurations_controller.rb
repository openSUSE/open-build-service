require 'configuration'

class ConfigurationsController < ApplicationController
  # Site-specific configuration is insensitive information, no login needed therefore
  skip_before_filter :extract_user, :only => [:show]
  before_filter :require_admin, :only => [:update]

  validate_action :show => {:method => :get, :response => :configuration}
  validate_action :update => {:method => :put, :request => :configuration}

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
      begin
        ret = @configuration.update_attributes(request.request_parameters)
      rescue ActiveRecord::UnknownAttributeError
        # User didn't really upload www-form-urlencoded data but raw XML, try to parse that
        xml = Xmlhash.parse(request.raw_post).get("configuration")
        attribs = {}
        attribs[:title] = xml["title"]
        attribs[:description] = xml["description"]
        ret = @configuration.update_attributes(attribs)
      end
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
