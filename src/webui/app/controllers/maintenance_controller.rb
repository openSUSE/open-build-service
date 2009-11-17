class MaintenanceController < ApplicationController

  skip_before_filter :require_login

  def index
    redirect_to :action => :released
  end
  
end
