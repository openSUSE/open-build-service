require 'app/controllers/status_controller.rb'

class StatusmonitorWorker

  def initialize
    @c = StatusController.new
  end

  def perform
    @c.update_workerstatus_cache
  end

end

