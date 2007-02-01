class MonitorController < ApplicationController
  def index
      @workerstatus = Workerstatus.find :all
  end
end
