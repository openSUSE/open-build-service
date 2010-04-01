class HomeController < ApplicationController
  
  before_filter :require_user

  def index
  end

  def list_requests
    @requests = @user.involved_requests(:cache => false)
  end

  private

  def require_user
    unless session[:login]
      @error_message = "There must be a user logged in to show the homepage"
      render :template => 'error'
    end

    unless check_user
      unless check_user
        raise "There is no user #{session[:login]} known in the system." unless @user
      end
    end
  end
end
