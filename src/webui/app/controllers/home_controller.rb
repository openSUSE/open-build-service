class HomeController < ApplicationController

  def index
    unless session[:login]
      @error_message = "There must be a user logged in to show the homepage"
      render :template => 'error'
    end

    logger.debug("Homepage for logged in user: #{session[:login]}")

    unless check_user
      raise "There is no user #{session[:login]} known in the system." unless @user
    end
  end

end
