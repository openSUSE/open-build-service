class UserController < ApplicationController
require 'opensuse/frontend'
  skip_before_filter :authorize, :transmit_credentials
  skip_before_filter :set_return_to, :only => [:login, :logout, :store_login, :register, :request_ichain]
  
  def login

  end
  
  def store_login
    login = params[:user_login]
    passwd = params[:user_password]

    session[:login] = login
    session[:passwd] = passwd
  
    if passwd 
      logger.debug "#{login} wants to log in with pwd XXX"
    else 
      logger.debug "#{login} wants to log in with empty passwd"
    end
    
    # render_text "Alles OK: #{session[:login]}"
    redirect_back_or_default url_for :action => 'login'
  end

  def logout
    logger.debug "Login in Session is #{session[:login]}"
    session[:login] = nil
    session[:passwd] = nil

    if ichain_mode != 'off'
      redirect_to '/cmd/ICSLogout'
    end
  end

  # store current uri in  the session.
  # we can return to this location by calling return_location
  def store_location
    logger.debug "storing :return_to : #{request.request_uri}"
    session[:return_to] = request.request_uri
  end

  # move to the last store_location call or to the passed default one 
  def redirect_back_or_default(default = url_for( :controller => ''))
    if session[:return_to].nil?
      logger.debug "redirecting to default url: #{default}"
      redirect_to default
    else
      logger.debug "redirecting to stored url: #{session[:return_to]}"
      redirect_to session[:return_to]
      session[:return_to] = nil
    end
  end

  def edit
    @user = Person.find :login => session[:login]
    session[:user] = @user
  end

  def save
    @user = session[:user]

    @user.realname.data.text = params[:realname]

    if @user.save
      flash[:note] = "User data for user '#{@user.login}' successfully saved."
    else
      flash[:note] = "Failed to save user data for user '#{user.login}'."
    end

    session[:user] = nil

    redirect_to :controller => "home"
  end

  def request_ichain
    logger.debug "#{session[:login]} is requesting ichain access!"
  end

  def register
     logger.debug "Creating new person #{session[:login]}"
     unreg_person_opts = {
       :login => session[:login],
       :email => session[:email],
       :realname => "",
       :explanation => ""
     }

     person = Unregisteredperson.new(unreg_person_opts)
     person.save

     redirect_back_or_default
  end

end
