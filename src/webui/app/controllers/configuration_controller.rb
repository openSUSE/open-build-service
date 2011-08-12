class ConfigurationController < ApplicationController

  before_filter :require_admin
  before_filter :require_available_architectures, :only => [:index, :update_architectures]

  def index
  end

  def connect_instance
  end

  def update_configuration
    valid_http_methods :post
    if ! (params[:title] || params[:target_project])
      flash[:error] = "Missing arguments (title or description)"
      redirect_back_or_to :action => 'index' and return
    end

    begin
      data = "title=#{CGI.escape(params[:title])}%20Open%20Build%20Service&description=#{CGI.escape(params[:description])}"
      response = ActiveXML::Config::transport_for(:configuration).direct_http(URI('/configuration'), :method => 'PUT', :content_type => 'application/x-www-form-urlencoded', :data => data)
      flash[:note] = "Updated configuration"
      Rails.cache.delete('configuration')
    rescue ActiveXML::Transport::Error => e
      logger.debug "Failed to update configuration"
      flash[:error] = "Failed to update configuration"
    end
    redirect_to :action => 'index'
  end

  def update_architectures
    valid_http_methods :post

    @available_architectures.each do |arch_elem|
      arch = Architecture.find_cached(arch_elem.name) # fetch a real 'Architecture' from 'directory' entry
      if params[:arch_recommended] and params[:arch_recommended].include?(arch.name) and arch.recommended.text == 'false'
        arch.recommended.text = 'true'
        arch.save
        Architecture.free_cache(:available)
      elsif arch.recommended.text == 'true'
        arch.recommended.text = 'false'
        arch.save
        Architecture.free_cache(:available)
      end
    end
    redirect_to :action => 'index'
  end

end
