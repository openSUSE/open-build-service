require 'base64'
require 'event'

class Webui::UserController < Webui::WebuiController

  include Webui::WebuiHelper
  include Webui::NotificationSettings

  before_filter :check_user, :only => [:edit, :save, :change_password, :register, :delete, :confirm,
                                       :lock, :admin, :login, :notifications, :update_notifications]
  before_filter :require_login, :only => [:edit, :save, :notifications, :update_notifications]
  before_filter :overwrite_user, :only => [:edit]
  before_filter :require_admin, :only => [:edit, :delete, :lock, :confirm, :admin]

  def logout
    logger.info "Logging out: #{session[:login]}"
    reset_session
    User.current = nil
    @return_to_path = root_path
    if CONFIG['proxy_auth_mode'] == :on
      redirect_to CONFIG['proxy_auth_logout_page']
    else
      redirect_to root_path
    end
  end

  def login
    @return_to_path = params['return_to_path'] || root_path
  end

  def do_login
    @return_to_path = params['return_to_path'] || root_path
    if params[:username].present? and params[:password]
      logger.debug "Doing form authorization to login user #{params[:username]}"
      session[:login] = params[:username]
      session[:password] = params[:password]
      authenticate_form_auth

      # TODO: remove again and use
      User.current = User.where(login: session[:login]).first
      begin
        ActiveXML.api.direct_http "/person/#{session[:login]}/login", method: 'POST'
      rescue ActiveXML::Transport::UnauthorizedError
        User.current = nil
      end
      unless User.current
        reset_session
        flash.now[:error] = 'Authentication failed'
        User.current = User.find_by_login('_nobody_')
        render :template => 'webui/user/login', :locals => { :return_to_path => @return_to_path }
        return
      end
      flash[:success] = 'You are logged in now'
      session[:login] = User.current.login
      redirect_to params[:return_to_path] and return
    end
    flash[:error] = 'Authentication failed'
    redirect_to :action => 'login'
  end

  def save
    if User.current.is_admin?
      person = User.find_by_login!(params[:user])
    else
      person = User.current
      if person.login != params[:user]
        flash[:error] = "Can't edit #{params[:user]}"
        redirect_to(:back) and return
      end
    end
    person.realname = params[:realname]
    person.email = params[:email]
    if User.current.is_admin?
      person.state = User.states[params[:state]]
      roles = [params[:globalrole]]
      person.update_globalroles(roles)
    end
    person.save!

    flash[:success] = "User data for user '#{person.login}' successfully updated."
    redirect_back_or_to :controller => 'home', :action => :index
  end

  def edit
    @roles = Role.global_roles
    @states = %w(confirmed unconfirmed deleted locked)
  end

  def delete
    u = User.find_by_login(params[:user])
    u.state = User.states['deleted']
    u.save
  end

  def confirm
    u = User.find_by_login(params[:user])
    u.state = User.states['confirmed']
    u.save
  end

  def lock
    u = User.find_by_login(params[:user])
    u.state = User.states['locked']
    u.save
  end

  def admin
    u = User.find_by_login(params[:user])
    u.update_globalroles(%w(Admin))
    u.save
  end

  def save_dialog
    @roles = Role.global_roles
    render_dialog
  end

  def overwrite_user
    @displayed_user = User.current
    user = User.find_by_login(params['user']) if params['user'].present?
    @displayed_user = user if user
  end

  private :overwrite_user


  def register
    opts = { :login => params[:login],
             :email => params[:email],
             :realname => params[:realname],
             :password => params[:password],
             :state => params[:state] }
    begin
      User.register(opts)
    rescue APIException => e
      flash[:error] = e.message
      redirect_back_or_to :controller => 'main', :action => 'index' and return
    end
    flash[:success] = "The account \"#{params[:login]}\" is now active."
    if User.current.is_admin?
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

  def password_dialog
    render_dialog
  end

  def change_password
    # check the valid of the params  
    if not params[:password] == session[:password]
      errmsg = 'The value of current password does not match your current password. Please enter the password and try again.'
    end
    if not params[:new_password] == params[:repeat_password]
      errmsg = 'The passwords do not match, please try again.'
    end
    if params[:password] == params[:new_password]
      errmsg = 'The new password is the same as your current password. Please enter a new password.'
    end
    if errmsg
      flash[:error] = errmsg
      redirect_to :controller => :home, :action => :index
      return
    end

    user = User.current
    user.update_password params[:new_password]
    user.save!

    session[:password] = params[:new_password]
    flash[:success] = 'Your password has been changed successfully.'
    redirect_to :controller => :home, :action => :index
  end

  def autocomplete
    required_parameters :term
    render json: list_users(params[:term])
  end

  def tokens
    required_parameters :q
    render json: list_users(params[:q], true)
  end

  def notifications
    notifications_for_user(User.current)
  end

  def update_notifications
    User.current.groups_users.each do |gu|
      gu.email = params[gu.group.title] == '1'
      gu.save
    end

    update_notifications_for_user(User.current)

    flash[:notice] = 'Notifications settings updated'
    redirect_to action: :notifications
  end

  protected

  def list_users(prefix=nil, hash=nil)
    names = []
    users = User.arel_table
    User.where(users[:login].matches("#{prefix}%")).pluck(:login).each do |user|
      if hash
        names << { 'name' => user }
      else
        names << user
      end
    end
    names
  end
end
