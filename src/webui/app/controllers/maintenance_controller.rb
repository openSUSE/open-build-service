class MaintenanceController < ApplicationController
  def index
    redirect_to :action => :released
  end

  def released
  end

  def qa
  end
end
