class UserController < ApplicationController

  before_filter :require_login, :only => [:edit, :save, :register]
  before_filter :check_user, :only => [:edit, :save, :change_password]

  def logout
    logger.info "Logging out: #{session[:login]}"
    reset_session
    @user = nil
    @return_to_path = "/"
    if ICHAIN_MODE == 'on'
      redirect_to '/cmd/ICSLogout'
    end
    Person.free_cache session
  end

  def login
    @return_to_path = params['return_to_path'] || "/"
  end
  
  def edit
  end

  def do_login
    @return_to_path = params['return_to_path'] || "/"
    if params[:username] and params[:password]
      logger.debug "Doing form authorization to login user #{params[:username]}"
      session[:login] = params[:username]
      session[:passwd] = params[:password]
      authenticate_form_auth
      begin
        Person.find( session[:login] )
      rescue ActiveXML::Transport::UnauthorizedError => exception
        logger.info "Login to #{@return_to_path} failed for #{session[:login]}: #{exception}"
        reset_session
        flash.now[:error] = "Authentication failed"
        render :template => "user/login", :locals => {:return_to_path => @return_to_path} and return
      end
      flash[:success] = "You are logged in now"
      redirect_to params[:return_to_path]
    end
  end

  def save
    @user.realname.text = params[:realname]
    if @user.save
      flash[:note] = "User data for user '#{@user.login}' successfully updated."
    else
      flash[:note] = "Failed to save user data for user '#{user.login}'."
    end
    session[:user] = nil
    redirect_to :controller => "home"
  end


  def register
    valid_http_methods(:post)
    begin
      find_cached(Person, session[:login] )
      logger.info "User #{session[:login]} already exists..."
      redirect_to :controller => :project, :action => :show, :project => "home:#{session[:login]}"
      return
    rescue
    end
    logger.debug "Creating new person #{session[:login]}"
    unreg_person_opts = {
      :login => session[:login],
      :email => session[:email] || 'nomail@nomail.com',
      :realname => "",
      :explanation => ""
    }
    person = Unregisteredperson.new(unreg_person_opts)
    person.save
    flash[:success] = "Your buildservice account is now active."
    redirect_to :controller => :project, :action => :show, :project => "home:#{session[:login]}"
  end

  def change_password
    # check the valid of the params  
    if not params[:current_password] == session[:passwd]
      errmsg = "The value of current password does not match your current password. Please enter the password and try again."
    end
    if not params[:new_password] == params[:password_confirmation]
      errmsg = "The new passwords do not match. Please enter the password and try again."
    end    
    if params[:current_password] == params[:new_password]
      errmsg = "The new password is the same as your current password. Please enter the new password again."
    end
    if errmsg:
      flash[:error] = errmsg
      redirect_to :controller => :user, :action => :change_my_password
      return
    end

    login = session[:login]
    require 'base64'     
    new_password = Base64.encode64(params[:new_password])
    begin
      path = "/person/#{login}/passwd/#{new_password}"
      result = frontend.transport.direct_http( URI(path) )
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
      redirect_to :controller => :user, :action => :change_my_password
      return
    end
    session[:passwd] = params[:new_password]
    flash[:success] = "Your password has been changed successfully."
    redirect_to :controller => :home, :action => :index
  end 

end
