class BackgroundrbStatusController < ApplicationController
  def index
    status = MiddleMan.all_worker_info
    render :text => status
  end
end
