require 'net/http'

module Webui
class HomeController < WebuiController

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
      @owned = ReverseOwner.find(:user => @displayed_user.login).each.map {|x| [x.package, x.project]} 
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

      if ::Configuration.use_gravatar?
        email = User.email_for_login(user)
        hash = Digest::MD5.hexdigest(email.downcase)
        begin
          content = ActiveXML.api.load_external_url("http://www.gravatar.com/avatar/#{hash}?s=#{size}&d=wavatar")
          content.force_encoding("ASCII-8BIT")
        rescue ActiveXML::Transport::Error
        end
      end

      content || 'none'
    end

    if content == 'none'
      redirect_to ActionController::Base.helpers.asset_path("default_face.png")
      return
    end

    expires_in 5.hours, public: true
    if stale?(etag: Digest::MD5.hexdigest(content))
      render text: content, layout: false, content_type: "image/png"
    end
  end

  def requests
    requests = @displayed_user.requests_that_need_work

    # Reviews
    @open_reviews = Webui::BsRequest.ids(requests['reviews'])
    @reviews_in = []
    @reviews_out = []
    @open_reviews.each do |review|
      if review["creator"] == @displayed_user.login
        @reviews_out << review
      else
        @reviews_in << review
      end
    end

    # Other requests
    @declined_requests = Webui::BsRequest.ids(requests['declined'])

    @open_requests = Webui::BsRequest.ids(requests['new'])
    @requests_in = []
    @requests_out = []
    @open_requests.each do |request|
      if request["creator"] == @displayed_user.login
        @requests_out << request
      else
        @requests_in << request
      end
    end


    @open_patchinfos = @displayed_user.running_patchinfos

    session[:requests] = (requests['declined'] + requests['reviews'] + requests['new'])

    @requests = @declined_requests + @open_reviews + @open_requests
    @default_request_type = params[:type] if params[:type]
    @default_request_state = params[:state] if params[:state]

    respond_to do |format|
      format.html
      format.json do
        rawdata = Hash.new
        rawdata["review"] = @open_reviews
        rawdata["new"] = @open_requests
        rawdata["declined"] = @declined_requests
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
    user = Person.find(params['user'] ) if params['user'].present?
    @displayed_user = user if user
    unless @displayed_user
      flash[:error] = "Please log in"
      redirect_to :controller => :user, :action => :login
    end
    logger.debug "Displayed user is #{@displayed_user}"
  end
  private :overwrite_user
end
end
