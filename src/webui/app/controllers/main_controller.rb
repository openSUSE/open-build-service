class MainController < ApplicationController

  def index
    @news = find_cached(Statusmessage, :conditions => 'deleted_at IS NULL', :order => 'create_at DESC', :limit => 5, :expires_in => 15.minutes)
    unless @spider_bot
      @latest_updates = find_cached(LatestUpdated, :limit => 6, :expires_in => 5.minutes, :shared => true)
      # first time login ?
      if @user and not find_cached(Project, "home:#{session[:login]}")
        if @user.is_admin?
          # go first to server configuration, afterwards to home directory creation
          redirect_to :controller => :configuration, :action => :connect_instance
        end
      end
    end
  rescue ActiveXML::Transport::UnauthorizedError
    @anonymous_forbidden = true
    logger.error "Could not load all frontpage data, probably due to forbidden anonymous access in the api."
  end

  # This action does the heavy lifting for the index method and is only invoked by an AJAX request
  def systemstatus
    render :text => 'no ajax', :status => 400 and return unless request.xhr? # Only serve AJAX-requests
    if @spider_bot
      @workerstatus = {}
    else
      @workerstatus = Rails.cache.fetch('frontpage_workerstatus', :expires_in => 15.minutes, :shared => true) do
        Workerstatus.find(:all).to_hash
      end
    end
    @waiting_packages = 0
    @workerstatus.elements("waiting") {|waiting| @waiting_packages += waiting["jobs"].to_i}
    @global_counters = find_cached(GlobalCounters, :expires_in => 15.minutes, :shared => true)
    @busy = nil
    require_available_architectures unless @spider_bot
    if @available_architectures
      @available_architectures.each.map {|arch| map_to_workers(arch.name) }.uniq.each do |arch|
        archret = frontend.gethistory("building_" + arch, 168).map {|time,value| [time,value]}
        if archret.length > 0
          if @busy
            @busy = MonitorController.addarrays(@busy, archret)
          else
            @busy = archret
          end
        end
      end
    end
    render :partial => 'main/systemstatus'
  rescue ActiveXML::Transport::UnauthorizedError 
    @anonymous_forbidden = true
    render :text => '' # AJAX-request means no 'flash' available, don't render anything if we aren't allowed
  end

  def news
    @news = find_cached(Statusmessage, :conditions => 'deleted_at IS NULL', :order => 'create_at DESC', :limit => 5, :expires_in => 15.minutes)
    respond_to do |format|
      format.rss { render :layout => false }
    end
  end

  def latest_updates
    @latest_updates = find_cached(LatestUpdated, :limit => 6, :expires_in => 5.minutes, :shared => true)
    respond_to do |format|
      format.rss { render :layout => false }
    end
  end

  def sitemap
    render :layout => false, :content_type => "application/xml"
  end

  def require_projects
    @projects = Array.new
    find_cached(Collection, :id, :what => "project").each_project do |p|
      @projects << p.value(:name)
    end
  end

  def sitemap_projects
    require_projects
    render :layout => false
  end
 
  def sitemap_projects_subpage(action, changefreq, priority)
    require_projects
    render :template => "main/sitemap_projects_subpage", :layout => false, :locals => { :action => action, :changefreq => changefreq, :priority => priority }
  end

  def sitemap_projects_packages
    sitemap_projects_subpage(:packages, 'monthly', 0.7)
  end

  def sitemap_projects_prjconf
    sitemap_projects_subpage(:prjconf, 'monthly', 0.1)
  end

  def sitemap_packages
    category = params[:category].to_s
    @packages = Array.new
    predicate = ''
    if category =~ %r{home}
      predicate = "starts-with(@project,'#{category}')"
    elsif category == 'opensuse'
      predicate = "starts-with(@project,'openSUSE:')"
    elsif category == 'main'
      predicate = "not(starts-with(@project,'home:')) and not(starts-with(@project,'DISCONTINUED:')) and not(starts-with(@project,'openSUSE:'))"
    end
    find_cached(Collection, :id, :what => 'package', :predicate => predicate).each_package do |p|
      @packages << [p.value(:project), p.value(:name)]
    end
    render :template => 'main/sitemap_packages', :layout => false, :locals => {:action => params[:listaction]}
  end

  def add_news_dialog
  end

  def add_news
    if params[:message].nil? or params[:severity].empty?
      flash[:error] = "Please provide a message and severity"
      redirect_to(:action => 'index') and return
    end

    begin
      message = Statusmessage.new(:message => params[:message], :severity => params[:severity])
      message.save
      Statusmessage.free_cache(:conditions => 'deleted_at IS NULL', :order => 'create_at DESC', :limit => 5)
    rescue ActiveXML::Transport::ForbiddenError
      flash[:error] = 'Only admin users may post status messages'
    end
    redirect_to(:action => 'index')
  end

  def delete_message_dialog
  end

  def delete_message
    message = Statusmessage.find(:id => params[:message_id])
    message.delete
    redirect_to(:action => 'index')
  rescue ActiveXML::Transport::ForbiddenError
    flash[:error] = 'Only admin users may delete status messages'
  end

  def require_available_architectures
    super # Call ApplicationController implementation, but catch an additional exception
  rescue ActiveXML::Transport::UnauthorizedError
    @anonymous_forbidden = true
    logger.error "Could not load all frontpage data, probably due to forbidden anonymous access in the api."
  end

  # we need a way so everyone 
  # of course we don't want to have this action visible 
  hide_action :startme unless Rails.env.test?
  def startme
     if Rails.env.test?
       frontend.transport.direct_http URI("/admin/startme")
     end
     render_error :status => 200, :message => "no error"
     return
  end

end
