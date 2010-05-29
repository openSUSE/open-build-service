require 'models/workerstatus'
require 'models/global_counters'
require 'models/latest_updated'

class MainController < ApplicationController

  def index
    @user ||= Person.find :login => session[:login] if session[:login]

    begin
      @workerstatus = Rails.cache.fetch('frontpage_workerstatus', :expires_in => 15.minutes) do
        Workerstatus.find :all
      end

      @waiting_packages = 0
      @workerstatus.each_waiting do |waiting|
        @waiting_packages += waiting.jobs.to_i
      end

      @global_counters = Rails.cache.fetch('global_stats', :expires_in => 15.minutes) do
        GlobalCounters.find( :all )
      end

      @latest_updates = Rails.cache.fetch('latest_updates', :expires_in => 5.minutes) do
        LatestUpdated.find( :limit => 6 )
      end

    rescue ActiveXML::Transport::UnauthorizedError => e
      @anonymous_forbidden = true
      logger.error "Could not load all frontpage data, probably due to forbidden anonymous access in the api."
    end

  end
  
  caches_page :sitemap, :sitemap_projects, :sitemap_packages_home, :sitemap_packages_main, :sitemap_packages_opensuse, :sitemap_projects_packages, :sitemap_projects_users

  def sitemap
    render :layout => false
  end

  def require_projects
    @projects = Array.new
    Collection.find_cached(:id, :what => "project").each_project do |p|
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
    sitemap_projects_subpage(:packages, 'weekly', 0.7)
  end

  def sitemap_projects_users
    sitemap_projects_subpage(:users, 'monthly', 0.1)
  end

  def sitemap_projects_attributes
    sitemap_projects_subpage(:attributes, 'weekly', 0.3)
  end

  def sitemap_projects_requests
    sitemap_projects_subpage(:list_requests, 'daily', 0.1)
  end
 
  def sitemap_projects_meta
    sitemap_projects_subpage(:meta, 'monthly', 0.1)
  end
 
  def sitemap_projects_prjconf
    sitemap_projects_subpage(:prjconf, 'monthly', 0.1)
  end

  def sitemap_projects_repositories
    sitemap_projects_subpage(:repositories, 'monthly', 0.1)
  end

  def sitemap_projects_subprojects
    sitemap_projects_subpage(:subprojects, 'weekly', 0.2)
  end

  def sitemap_packages_home
    @packages = Array.new
    Collection.find_cached(:id, :what => "package", :predicate => "starts-with(@project,'home:')").each_package do |p|
      @packages << [p.value(:project), p.value(:name)]
    end
    render :template => 'main/sitemap_packages', :layout => false
  end

  def sitemap_packages_opensuse
    @packages = Array.new
    Collection.find_cached(:id, :what => "package", :predicate => "starts-with(@project,'openSUSE:')").each_package do |p|
      @packages << [p.value(:project), p.value(:name)]
    end
    render :template => 'main/sitemap_packages', :layout => false
  end

  def sitemap_packages_main
    @packages = Array.new
    Collection.find_cached(:id, :what => "package", :predicate => "not(starts-with(@project,'home:')) and not(starts-with(@project,'DISCONTINUED:')) and not(starts-with(@project,'openSUSE:'))").each_package do |p|
      @packages << [p.value(:project), p.value(:name)]
    end
    render :template => 'main/sitemap_packages', :layout => false
  end
end
