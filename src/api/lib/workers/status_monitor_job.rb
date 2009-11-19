#require File.join(RAILS_ROOT, 'app/controllers/status_controller.rb')

class StatusMonitorJob

  def initialize
  end

  def perform
    c = StatusController.new
    c.update_workerstatus_cache
  end

end

