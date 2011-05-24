class HomeController < ApplicationController
  
  before_filter :require_login
  before_filter :check_user
  
  def index
    user = find_cached(Person, params['user'] ) if params['user']
    @user = user if user
  end

  def my_work
    user = find_cached(Person, params['user'] ) if params['user']
    @user = user if user
    @new_requests = BsRequest.list({:states => 'new', :roles => "maintainer", :user => user.to_s})
    @open_reviews = BsRequest.list({:states => 'review', :reviewstates => 'new', :roles => "reviewer", :user => user.to_s})
  end

  def list_requests
    user = find_cached(Person, params['user'] ) if params['user']
    @user = user if user
    @requests = @user.involved_requests(:cache => false)
  end

  def home_project
    redirect_to :controller => :project, :action => :show, :project => "home:#{@user}"
  end

  def list_my
    user = find_cached(Person, params['user'] ) if params['user']
    @user = user if user
    @user.free_cache if discard_cache?
    set_watchlist @user
    @iprojects = @user.involved_projects.each.map {|x| x.name}.uniq.sort
    @ipackages = Hash.new
    pkglist = @user.involved_packages.each.reject {|x| @iprojects.include?(x.project)}
    pkglist.sort(&@user.method('packagesorter')).each do |pack|
      @ipackages[pack.project] ||= Array.new
      @ipackages[pack.project] << pack.name if !@ipackages[pack.project].include? pack.name
    end
  end

  def remove_watched_project
    project = params[:project]
    if check_user
      logger.debug "removing watched project '#{project}' from user '#@user'"
      @user.remove_watched_project project
      @user.save
      set_watchlist @user
      render :partial => 'watch_list'
    end
  end

  #extract a list of project names and sort them case insensitive
  def set_watchlist user
    if user.has_element? :watchlist
      @watchlist = user.watchlist.each_project.map {|p| p.name }.sort {|a,b| a.downcase <=> b.downcase }
    end
  end

end
