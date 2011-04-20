class UserController < ApplicationController

  include ApplicationHelper

  before_filter :require_login, :only => [:edit, :save]
  before_filter :check_user, :only => [:edit, :save, :change_password]

  def logout
    logger.info "Logging out: #{session[:login]}"
    reset_session
    @user = nil
    @return_to_path = "/"
    if PROXY_AUTH_MODE == :on
      redirect_to PROXY_AUTH_LOGOUT_PAGE
    else
      redirect_to '/'
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
        p = Person.find( session[:login] )
      rescue ActiveXML::Transport::UnauthorizedError => exception
        logger.info "Login to #{@return_to_path} failed for #{session[:login]}: #{exception}"
        reset_session
        flash.now[:error] = "Authentication failed"
        render :template => "user/login", :locals => {:return_to_path => @return_to_path} and return
      end
      unless p
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
      redirect_to :controller => :project, :action => :show, :project => "home:#{session[:login]}" and return
    rescue
    end
    login = ""
    realname = ""
    explanation = ""

    # User entered data
    login       = params[:login]       if params[:login]
    email       = params[:email]       if params[:email]
    realname    = params[:realname]    if params[:realname]
    explanation = params[:explanation] if params[:explanation]

    # session data, when login via iChain for example
    login = session[:login] if session[:login]
    email = session[:email] || 'nomail@nomail.com'

    if params[:password_first] != params[:password_second]
      logger.info "Password did not match"
      flash[:error] = "Given passwords are not the same"
      redirect_back_or_to :controller => "main", :action => "index" and return
    end
    if params[:password_first] and (params[:password_first].length < 6 or params[:password_first].length > 64)
      flash[:error] = "Password is to short, it should have minimum 6 characters"
      redirect_back_or_to :controller => "main", :action => "index" and return
    end
    if login.blank? or login.include?(" ")
      logger.info "Illegal login name"
      flash[:error] = "Illegal login name"
      redirect_back_or_to :controller => "main", :action => "index" and return
    end
    #FIXME redirecting destroys form content, either send it or use AJAX form validation

    logger.debug "Creating new person #{login}"
    unreg_person_opts = {
      :login => login,
      :email => email,
      :realname => realname,
      :explanation => explanation
    }
    unreg_person_opts[:password] = params[:password_first] if params[:password_first]

    person = Unregisteredperson.new(unreg_person_opts)
    person.save({:create => true})

    session[:login] = login
    session[:passwd] = unreg_person_opts[:password]
    authenticate_form_auth

    flash[:success] = "Your buildservice account is now active."
    redirect_to :controller => :project, :action => :new, :project => "home:#{login}"
  end

  def change_password
    valid_http_methods(:post)
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

    require 'base64' 
    new_password = Base64.encode64(params[:new_password]).chomp    
    changepwd = Userchangepasswd.new(:login => session[:login], :password => new_password)
    
    begin
      if changepwd.save(:create => true)
        session[:passwd] = params[:new_password]
        flash[:success] = "Your password has been changed successfully."
        redirect_to :controller => :home, :action => :index
        return
      else
        flash[:error] = "Failed to change your password."
      end
    rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      flash[:error] = message
    end

    redirect_to :controller => :user, :action => :change_my_password
  end 

  def autocomplete_users
    required_parameters :q
    @users = Person.list(params[:q])
    render :text => @users.join("\n")
  end

end
