require 'models/workerstatus'
require 'models/global_counters'
require 'models/latest_updated'

class MainController < ApplicationController

  before_filter :require_available_architectures, :only => [:index]

  def index
    @user ||= Person.find :login => session[:login] if session[:login]

    begin
      @workerstatus = Rails.cache.fetch('frontpage_workerstatus', :expires_in => 15.minutes, :shared => true) do
        Workerstatus.find :all
      end

      @waiting_packages = 0
      if @workerstatus
        @workerstatus.each_waiting do |waiting|
          @waiting_packages += waiting.jobs.to_i
        end
      end

      @busy = nil
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

      @global_counters = Rails.cache.fetch('global_stats', :expires_in => 15.minutes, :shared => true) do
        GlobalCounters.find( :all )
      end
      key="latest_updates_#{@user}"
      @latest_updates = Rails.cache.fetch(key, :expires_in => 5.minutes, :shared => true) do
        LatestUpdated.find( :limit => 6 )
      end

    rescue ActiveXML::Transport::UnauthorizedError => e
      @anonymous_forbidden = true
      logger.error "Could not load all frontpage data, probably due to forbidden anonymous access in the api."
    end

  end
  
  def sitemap
    render :layout => false
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

  def sitemap_projects_users
    sitemap_projects_subpage(:users, 'monthly', 0.1)
  end

  def sitemap_projects_attributes
    sitemap_projects_subpage(:attributes, 'monthly', 0.3)
  end

  def sitemap_projects_requests
    sitemap_projects_subpage(:list_requests, 'monthly', 0.1)
  end
 
  def sitemap_projects_prjconf
    sitemap_projects_subpage(:prjconf, 'monthly', 0.1)
  end

  def load_packages(category)
    category = category.to_s
    @packages = Array.new
    if category == 'home'
      find_cached(Collection, :id, :what => "package", :predicate => "starts-with(@project,'home:')").each_package do |p|
        @packages << [p.value(:project), p.value(:name)]
      end
    elsif category == 'opensuse'
      find_cached(Collection, :id, :what => "package", :predicate => "starts-with(@project,'openSUSE:')").each_package do |p|
        @packages << [p.value(:project), p.value(:name)]
      end
    elsif category == 'main'
       find_cached(Collection, :id, :what => "package", :predicate => "not(starts-with(@project,'home:')) and not(starts-with(@project,'DISCONTINUED:')) and not(starts-with(@project,'openSUSE:'))").each_package do |p|
         @packages << [p.value(:project), p.value(:name)]
       end
    end
  end

  def sitemap_packages
    load_packages(params[:category])
    render :template => 'main/sitemap_packages', :layout => false, :locals => { :action => params[:listaction] }
  end

  def require_available_architectures
    begin
      transport = ActiveXML::Config::transport_for(:architecture)
      response = transport.direct_http(URI("/architectures?available=1"), :method => "GET")
      @available_architectures = Collection.new(response)
    rescue ActiveXML::Transport::NotFoundError
      flash[:error] = "Available architectures not found: #{params[:project]}"
      redirect_to :controller => "project", :action => "list_public", :nextstatus => 404
    rescue ActiveXML::Transport::UnauthorizedError => e
      @anonymous_forbidden = true
      logger.error "Could not load all frontpage data, probably due to forbidden anonymous access in the api."
    end
  end

end
