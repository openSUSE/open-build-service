class HomeController < ApplicationController

  def index
    logger.debug("Homepage for logged in user: #{session[:login]}")

    @user = Person.find( :login => session[:login] )
    
    unless @user
      @error_message = "There is no user <b>#{session[:login]}</b> known in the system."
      render :template => 'error'
    end
  end
  
end
