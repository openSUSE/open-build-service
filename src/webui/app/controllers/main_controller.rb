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
  
  caches_page :sitemap, :sitemap_projects, :sitemap_packages_home, :sitemap_packages_main, :sitemap_packages_opensuse

  def sitemap
    render :layout => false
  end

  def sitemap_projects
    @projects = Array.new
    Collection.find_cached(:id, :what => "project").each_project do |p|
      @projects << p.value(:name)
    end
    render :layout => false
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
