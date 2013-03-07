require 'base64'

class UserController < ApplicationController

  include ApplicationHelper

  before_filter :require_login, :only => [:edit, :save]
  before_filter :check_user, :only => [:edit, :save, :change_password, :register, :delete, :confirm, :lock, :admin]
  before_filter :overwrite_user, :only => [:edit]
  
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
    person_opts = { :login => params[:user],
                    :realname => params[:realname],
                    :email => params[:email],
                    :globalrole => params[:globalrole],
                    :state => params[:state]}
    begin
      person = Person.new(person_opts)
      person.save
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.message
    end
    flash[:success] = "User data for user '#{person.login}' successfully updated."
    Rails.cache.delete("person_#{person.login}")
    if @user and @user.is_admin?
      redirect_to :controller => :configuration, :action => :users
    else
      redirect_to :controller => "home", :user => params[:user]
    end
  end

  def edit
    @roles = Role.global_roles
    @states = State.states
  end

  def delete
    user = Person.find( params[:user] )
    params[:realname] = user.realname
    params[:email] = user.email
    params[:globalrole] = user.globalrole
    params[:state] = 'deleted'
    save
  end

  def confirm
    user = Person.find( params[:user] )
    params[:realname] = user.realname
    params[:email] = user.email
    params[:globalrole] = user.globalrole
    params[:state] = 'confirmed'
    save
  end
  
  def lock
    user = Person.find( params[:user] )
    params[:realname] = user.realname
    params[:email] = user.email
    params[:globalrole] = user.globalrole
    params[:state] = 'locked'
    save
  end

  def admin
    user = Person.find( params[:user] )
    params[:realname] = user.realname
    params[:email] = user.email
    params[:globalrole] = 'Admin'
    params[:state] = user.state
    save
  end

  def save_dialog
    check_ajax
    @roles = Role.global_roles
  end

  def overwrite_user
    @displayed_user = @user
    user = find_cached(Person, params['user'] ) if params['user'] && !params['user'].empty?
    @displayed_user = user if user
  end
  private :overwrite_user


  def register
    unreg_person_opts = { :login => params[:login],
                          :email => params[:email],
                          :realname => params[:realname],
                          :password => params[:password],
                          :state => params[:state]}
    begin
      person = Unregisteredperson.new(unreg_person_opts)
      logger.debug "Registering user #{params[:login]}"
      person.save({:create => true})
    rescue ActiveXML::Transport::Error => e
      flash[:error] = e.message
      redirect_back_or_to :controller => "main", :action => "index" and return
    end
    flash[:success] = "The account \"#{params[:login]}\" is now active."
    if @user and @user.is_admin?
      redirect_to :controller => :configuration, :action => :users
    else
     session[:login] = unreg_person_opts[:login]
     session[:password] = unreg_person_opts[:password]
     authenticate_form_auth
     redirect_back_or_to :controller => :main, :action => :index
    end
  end

  def register_user
  end

  def change_password
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
      flash[:error] = e.summary
    end

    redirect_to :controller => :user, :action => :change_my_password
  end 

  def autocomplete
    required_parameters :term
    render json: Person.list(params[:term])
  end

  def tokens
    required_parameters :q
    render json: Person.list(params[:q], true)
  end

end
