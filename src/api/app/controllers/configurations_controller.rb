require 'configuration'

class ConfigurationsController < ApplicationController
  # Site-specific configuration is insensitive information, no login needed therefore
  before_action :require_admin, only: [:update]
  skip_before_action :validate_params, only: [:update] # we use an array for archs here

  validate_action show: {method: :get, response: :configuration}
  # webui is using this route with parameters instead of content
  #  validate_action :update => {:method => :put, :request => :configuration}

  # GET /configuration
  # GET /configuration.xml
  # GET /configuration.json
  def show
    @configuration = ::Configuration.first

    respond_to do |format|
      format.xml  { render xml: @configuration.render_xml }
      format.json { render json: @configuration.to_json }
    end
  end

  # PUT /configuration
  # PUT /configuration.xml
  def update
    @configuration = ::Configuration.first

    xml = Xmlhash.parse(request.raw_post) || {}
    attribs = {}
    # scheduler architecture list
    archs = nil
    archs = Hash[xml["schedulers"]["arch"].map {|a| [a, 1]}] if xml["schedulers"] && xml["schedulers"]["arch"].class == Array
    archs = Hash[params["arch"].map {|a| [a, 1]}] if params["arch"].class == Array
    if archs
      Architecture.all.each do |arch|
        if arch.available != (archs[arch.name] == 1)
          arch.available = (archs[arch.name] == 1)
          arch.save!
        end
      end
    end

    # standard values as defined in model
    keys = ::Configuration::OPTIONS_YML.keys
    keys.each do |key|
      # either from xml or via parameters
      value = xml[key.to_s] || params[key.to_s]

      # is it defined in options.yml
      if value && !value.blank?
        v = ::Configuration.map_value( key, value )
        ov = ::Configuration.map_value( key, ::Configuration::OPTIONS_YML[key] )
        if ov != v && ov.present?
          render_error status: 403, errorcode: 'no_permission_to_change',
                       message: "The api has a different value for #{key} configured in options.yml file. Remove it there first."
          return
        end
        attribs[key] = value
      end
    end

    ret = @configuration.update_attributes(attribs)
    if ret
      @configuration.save!
      head :ok
    else
      render xml: @configuration.errors, status: :unprocessable_entity
    end
  end
end
