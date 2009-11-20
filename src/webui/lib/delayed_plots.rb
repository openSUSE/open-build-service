require File.join(RAILS_ROOT, 'app/controllers/monitor_controller.rb')

class DelayedPlots
  def initialize(hours)
       @hours = hours 
  end

  def perform
    m = MonitorController.new
    MONITOR_IMAGEMAP.each do |key, array|
       m.plothistory_cache(key, @hours)
    end
  end
end

