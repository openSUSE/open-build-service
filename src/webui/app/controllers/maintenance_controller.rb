class MaintenanceController < ApplicationController

  skip_before_filter :require_login

  def index
    redirect_to :action => :released
  end

  def released
  end

  def qa
  end

  def new
  end
  
end
