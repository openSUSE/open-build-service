class ConfigurationController < ApplicationController

  before_filter :require_admin

  def index
  end

  def connect_instance
  end

  def update_configuration
    valid_http_methods :post
    if not (params[:title] or params[:target_project])
      flash[:error] = "Missing arguments (title or description)"
      redirect_back_or_to :action => 'index' and return
    end

    begin
      data = "title=#{CGI.escape(params[:title])}&description=#{CGI.escape(params[:description])}"
      response = ActiveXML::Config::transport_for(:configuration).direct_http(URI('/configuration'), :method => 'PUT', :content_type => 'application/x-www-form-urlencoded', :data => data)
      flash[:note] = "Updated configuration"
      Rails.cache.delete('configuration')
    rescue ActiveXML::Transport::Error => e
      logger.debug "Failed to update configuration"
      flash[:error] = "Failed to update configuration"
    end
    redirect_to :action => 'index'
  end

end
