class MonitorController < ApplicationController
  def index
    if request.post? && ! params[:project].nil?
      redirect_to :project => params[:project]
    else
      @workerstatus = Workerstatus.find :all
    end
  end
end
