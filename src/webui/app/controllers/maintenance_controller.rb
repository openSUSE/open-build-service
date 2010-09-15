class MaintenanceController < ApplicationController

  skip_before_filter :require_login
  before_filter :set_content_type
  
  def index
    redirect_to :action => :released
  end

  private

  def set_content_type
    headers["Content-Type"] = "text/html; charset=utf-8"
  end

end
