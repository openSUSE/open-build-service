require 'net/http'

#noinspection ALL
class HomeController < ApplicationController

  before_filter :require_login, :except => [:icon, :index, :requests]
  before_filter :check_user, :except => [:icon]
  before_filter :overwrite_user, :only => [:index, :requests, :list_my]

  def index
    lockout_spiders
    @displayed_user.free_cache if discard_cache?
    @iprojects = @displayed_user.involved_projects.each.collect! do |x|
      ret =[]
      ret << x.name
      if x.to_hash['title'].class == Xmlhash::XMLHash
        ret << "No title set"
      else
        ret << x.to_hash['title']
      end
    end
    @ipackages = @displayed_user.involved_packages.each.map {|x| [x.name, x.project]}
    begin
      @owned = ReverseOwner.find_cached(:user => @displayed_user.login).each.map {|x| [x.rootproject, x.package, x.project]} 
      # :limit => "#{@owner_limit}", :devel => "#{@owner_devel}"
    rescue ActiveXML::Transport::Error
    # OBSRootOwner isn't set...
      @owned = []
    end
    if @user == @displayed_user
      requests
    end
  end
  
  def icon
    required_parameters :user
    user = params[:user]
    size = params[:size] || '20'
    key = "home_face_#{user}_#{size}"
    Rails.cache.delete(key) if discard_cache?
    content = Rails.cache.fetch(key, :expires_in => 5.hours) do

      unless CONFIG['use_gravatar'] == :off
        email = Person.email_for_login(user)
        hash = Digest::MD5.hexdigest(email.downcase)
        content = ActiveXML.transport.load_external_url("http://www.gravatar.com/avatar/#{hash}?s=#{size}&d=wavatar")
      end

      unless content
        #TODO/FIXME: Looks like an asset...
        f = File.open("#{Rails.root}/app/assets/images/default_face.png", "r")
        content = f.read
        f.close
      end
      content.force_encoding("ASCII-8BIT")
    end

    expires_in 5.hours, public: true
    if stale?(etag: Digest::MD5.hexdigest(content))
      render text: content, layout: false, content_type: "image/png"
    end
  end

  def requests
    requests = @displayed_user.requests_that_need_work
    @declined_requests = BsRequest.ids(requests['declined'])
    @open_reviews = BsRequest.ids(requests['reviews'])
    @new_requests = BsRequest.ids(requests['new'])
    @open_patchinfos = @displayed_user.running_patchinfos
    session[:requests] = (requests['declined'] + requests['reviews'] + requests['new'])    
    @requests = BsRequest.ids(session[:requests])
    @default_request_type = params[:type] if params[:type]
    @default_request_state = params[:state] if params[:state]

    respond_to do |format|
      format.html
      format.json do
        rawdata = Hash.new
        rawdata["declined"] = @declined_requests
        rawdata["review"] = @open_reviews
        rawdata["new"] = @new_requests
        rawdata["patchinfos"] = @open_patchinfos
        render :text => JSON.pretty_generate(rawdata)
      end
    end
  end

  def home_project
    redirect_to :controller => :project, :action => :show, :project => "home:#{@user}"
  end

  def remove_watched_project
    logger.debug "removing watched project '#{params[:project]}' from user '#{@user}'"
    @user.remove_watched_project(params[:project])
    @user.save
    render :partial => 'watch_list'
  end

  def overwrite_user
    @displayed_user = @user
    user = find_cached(Person, params['user'] ) if params['user'] && !params['user'].empty?
    @displayed_user = user if user
    unless @displayed_user
      flash[:error] = "Please log in"
      redirect_to :controller => :user, :action => :login
    end
    logger.debug "Displayed user is #{@displayed_user}"
  end
  private :overwrite_user
end
