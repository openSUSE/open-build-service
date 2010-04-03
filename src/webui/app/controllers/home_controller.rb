class HomeController < ApplicationController
  
  before_filter :require_login
  before_filter :check_user
  
  def index
  end

  def list_requests
    @requests = @user.involved_requests(:cache => false)
  end


end
