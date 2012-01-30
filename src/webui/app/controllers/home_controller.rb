class HomeController < ApplicationController

  before_filter :require_login, :except => [:my_work]
  before_filter :check_user
  before_filter :overwrite_user, :only => [:index, :my_work, :requests, :list_my]

  def index
  end

  def my_work
    unless @displayed_user
      require_login 
      return
    end
    @declined_requests, @open_reviews, @new_requests = @displayed_user.requests_that_need_work(:cache => false)
    @open_patchinfos = @displayed_user.running_patchinfos(:cache => false)
  end

  def requests
    @requests = @displayed_user.involved_requests(:cache => false)
  end

  def home_project
    redirect_to :controller => :project, :action => :show, :project => "home:#{@user}"
  end

  def list_my
    @displayed_user.free_cache if discard_cache?
    @iprojects = @displayed_user.involved_projects.each.map {|x| x.name}.uniq.sort
    @ipackages = Hash.new
    pkglist = @displayed_user.involved_packages.each.reject {|x| @iprojects.include?(x.project)}
    pkglist.sort(&@displayed_user.method('packagesorter')).each do |pack|
      @ipackages[pack.project] ||= Array.new
      @ipackages[pack.project] << pack.name if !@ipackages[pack.project].include? pack.name
    end
  end

  def remove_watched_project
    logger.debug "removing watched project '#{params[:project]}' from user '#@user'"
    @user.remove_watched_project(params[:project])
    @user.save
    render :partial => 'watch_list'
  end

  def overwrite_user
    @displayed_user = @user
    user = find_cached(Person, params['user'] ) if params['user']
    @displayed_user = user if user
  end
  private :overwrite_user
end
