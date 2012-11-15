require 'base64'

class UserController < ApplicationController

  include ApplicationHelper

  before_filter :require_login, :only => [:edit, :save]
  before_filter :check_user, :only => [:edit, :save, :change_password]

  def logout
    logger.info "Logging out: #{session[:login]}"
    reset_session
    @user = nil
    @return_to_path = "/"
    if CONFIG['proxy_auth_mode'] == :on
      redirect_to CONFIG['proxy_auth_logout_page']
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
    if !params[:username].blank? and params[:password]
      logger.debug "Doing form authorization to login user #{params[:username]}"
      session[:login] = params[:username]
      session[:password] = params[:password]
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
      redirect_to params[:return_to_path] and return
    end
    flash[:error] = "Authentication failed"
    redirect_to :action => 'login'
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
    unless CONFIG['frontend_ldap_mode'] == :off
      flash[:error] = 'Registering currently not possible with LDAP mode'
      redirect_back_or_to :controller => 'main', :action => 'index' and return
    end
    begin
      find_cached(Person, session[:login] )
      logger.info "User #{session[:login]} already exists..."
      redirect_to :controller => :project, :action => :show, :project => "home:#{session[:login]}" and return
    rescue
    end

    #FIXME: Reading form data and overriding it with session data seems broken.
    #       Saving it back into the session seems even more so, re-evaluate this.
    login = session[:login] || params[:login] || ''
    email = session[:email] || params[:email] || 'nomail@nomail.com'

    #FIXME redirecting destroys form content, either send it or use AJAX form validation
    if login.blank? or login.include?(" ")
      flash[:error] = "Illegal login name"
      redirect_back_or_to :controller => "main", :action => "index" and return
    end
    simplified_rfc2822_regexp = Regexp.new '\A[a-z0-9!#$%&\'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&\'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\Z'
    if email !~ simplified_rfc2822_regexp
      flash[:error] = "Illegal email address: #{email}"
      redirect_back_or_to :controller => "main", :action => "index" and return
    end
    if params[:password_first] != params[:password_second]
      flash[:error] = "Given passwords are not the same"
      redirect_back_or_to :controller => "main", :action => "index" and return
    end
    if params[:password_first] and (params[:password_first].length < 6 or params[:password_first].length > 64)
      flash[:error] = "Password is to short, it should have minimum 6 characters"
      redirect_back_or_to :controller => "main", :action => "index" and return
    end

    logger.debug "Creating new person #{login}"
    unreg_person_opts = { :login => login, :email => email, :realname => params[:realname], :explanation => params[:description] }
    unreg_person_opts[:password] = params[:password_first] if params[:password_first]

    begin
      person = Unregisteredperson.new(unreg_person_opts)
      person.save({:create => true})
    rescue ActiveXML::Transport::Error => e
      message = ActiveXML::Transport.extract_error_message(e)[0]
      flash[:error] = message
      redirect_back_or_to :controller => "main", :action => "index" and return
    end

    session[:login] = login
    session[:password] = unreg_person_opts[:password]
    authenticate_form_auth

    flash[:success] = "Your buildservice account is now active."
    redirect_to :controller => :project, :action => :new, :ns => "home:#{login}"
  end

  def register_user
  end

  def change_password
    valid_http_methods(:post)
    # check the valid of the params  
    if not params[:current_password] == session[:password]
      errmsg = "The value of current password does not match your current password. Please enter the password and try again."
    end
    if not params[:new_password] == params[:password_confirmation]
      errmsg = "The new passwords do not match. Please enter the password and try again."
    end    
    if params[:current_password] == params[:new_password]
      errmsg = "The new password is the same as your current password. Please enter the new password again."
    end
    if errmsg
      flash[:error] = errmsg
      redirect_to :controller => :user, :action => :change_my_password
      return
    end

    # Replace all '\n' characters (not just the last one) that Ruby thinks belong into
    # Base64 encoded strings. Happens when people enter lengthy passwords with more than
    # 60 characters (the Base64 module's magically hardcoded linebreak default).
    new_password = Base64.encode64(params[:new_password]).gsub("\n", "")
    changepwd = Userchangepasswd.new(:login => session[:login], :password => new_password)

    begin
      if changepwd.save(:create => true)
        session[:password] = params[:new_password]
        flash[:success] = "Your password has been changed successfully."
        redirect_to :controller => :home, :action => :index
        return
      else
        flash[:error] = "Failed to change your password."
      end
    rescue ActiveXML::Transport::Error => e
      message = ActiveXML::Transport.extract_error_message(e)[0]
      flash[:error] = message
    end

    redirect_to :controller => :user, :action => :change_my_password
  end 

  def autocomplete
    required_parameters :term
    render :json => Person.list(params[:term])
  end

end
