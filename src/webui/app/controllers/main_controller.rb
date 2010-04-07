require 'models/workerstatus'
require 'models/global_counters'

class MainController < ApplicationController

  before_filter :check_user, :only => [ :index ]

  def index
    @user ||= Person.find :login => session[:login] if session[:login]
    cache_key = 'frontpage_workerstatus'
    if !(@workerstatus = Rails.cache.read(cache_key))
      @workerstatus = Workerstatus.find :all
      Rails.cache.write(cache_key, @workerstatus, :expires_in => 15.minutes)
    end

    @waiting_packages = 0
    @workerstatus.each_waiting do |waiting|
      @waiting_packages += waiting.jobs.to_i
    end

    if !(@global_counters = Rails.cache.read('global_stats'))
      @global_counters = GlobalCounters.find( :all )
      Rails.cache.write('global_stats', @global_counters, :expires_in => 15.minutes)
    end
  end   

  
end
