class ConfigurationsController < ApplicationController
  # Site-specific configuration is insensitive information, no login needed therefore
  skip_before_filter :extract_user, :only => [:show]

  # GET /configuration
  # GET /configuration.json
  # GET /configuration.xml
  def show
    @configuration = Configuration.first

    respond_to do |format|
      format.xml  { render :xml => @configuration }
      format.html # show.html.erb
      format.json { render :json => @configuration }
    end
  end

  # GET /configuration/edit
  def edit
    @configuration = Configuration.first
  end

  # PUT /configuration
  # PUT /configuration.json
  # PUT /configuration.xml
  def update
    unless @http_user.is_admin?
      render_error :status => 403, :errorcode => "put_request_no_permission", :message => "PUT on requests currently requires admin privileges" and return
    end
    @configuration = Configuration.first

    respond_to do |format|
      if @configuration.update_attributes(request.request_parameters)
        format.xml  { head :ok }
        format.html { redirect_to(@configuration, :notice => 'Configuration was successfully updated.') }
        format.json { head :ok }
      else
        format.xml  { render :xml => @configuration.errors, :status => :unprocessable_entity }
        format.html { render :action => "edit" }
        format.json { render :json => @configuration.errors, :status => :unprocessable_entity }
      end
    end
  end
end
