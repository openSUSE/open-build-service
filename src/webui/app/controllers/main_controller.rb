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
  
end
