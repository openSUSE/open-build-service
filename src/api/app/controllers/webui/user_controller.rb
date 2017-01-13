require 'base64'
require 'event'

class Webui::UserController < Webui::WebuiController

  include Webui::WebuiHelper
  include Webui::NotificationSettings

  before_filter :check_user, :only => [:edit, :save, :change_password, :register, :delete, :confirm,
                                       :lock, :admin, :login, :notifications, :update_notifications, :show]
  before_filter :require_login, :only => [:edit, :save, :notifications, :update_notifications]
  before_filter :overwrite_user, :only => [:show, :edit, :requests, :list_my]
  before_filter :require_admin, :only => [:edit, :delete, :lock, :confirm, :admin]
  
  skip_before_action :check_anonymous, only: [:do_login]

  def logout
    logger.info "Logging out: #{session[:login]}"
    Rails.cache.delete("ldap_cache_userpasswd:#{session[:login]}")
    reset_session
    User.current = nil
    if CONFIG['proxy_auth_mode'] == :on
      redirect_to CONFIG['proxy_auth_logout_page']
    else
      redirect_to root_path
    end
  end

  def login
  end

  def do_login
    if params[:username].present? && params[:password]
      logger.debug "Doing form authorization to login user #{params[:username]}"

      session[:login] = params[:username]
      session[:password] = params[:password]
      authenticate_form_auth

      begin
        ActiveXML.api.direct_http "/person/#{session[:login]}/login", method: 'POST'
        # TODO: remove again and use
        User.current = User.where(login: session[:login]).first
      rescue ActiveXML::Transport::UnauthorizedError
        User.current = nil
      end

      unless User.current
        reset_session
        flash[:error] = 'Authentication failed'
        User.current = User.find_by_login('_nobody_')
        redirect_to action: 'login'
        return
      end

      flash[:success] = 'You are logged in now'
      session[:login] = User.current.login
      if request.referer.end_with?("/user/login")
        redirect_to home_path
      else
        redirect_back_or_to root_path
      end
      return
    end
    flash[:error] = 'Authentication failed'
    redirect_to :action => 'login'
  end

  def show
    if params['user'].present?
      begin
        @displayed_user = User.find_by_login!(params['user'])
      rescue NotFoundError
        redirect_to :back, error: "User not found #{params['user']}"
      end
    end
    @iprojects = @displayed_user.involved_projects.pluck(:name, :title)
    @ipackages = @displayed_user.involved_packages.joins(:project).pluck(:name, 'projects.name as pname')
    @owned = @displayed_user.owned_packages

    if User.current == @displayed_user
        @reviews = @displayed_user.involved_reviews
        @patchinfos = @displayed_user.involved_patchinfos
        @requests_in = @displayed_user.incoming_requests
        @requests_out = @displayed_user.outgouing_requests
        @declined_requests = @displayed_user.declined_requests
    end
  end

  def home
    if params[:user].present?
      redirect_to :action => :show, user: params[:user]
    else
      redirect_to :action => :show, user: User.current
    end
  end

  def requests
    session[:requests] = @displayed_user.declined_requests.pluck(:id) + @displayed_user.involved_reviews.map { |r| r.id } + @displayed_user.incoming_requests.pluck(:id)
    @requests = @displayed_user.declined_requests + @displayed_user.involved_reviews + @displayed_user.incoming_requests
    @default_request_type = params[:type] if params[:type]
    @default_request_state = params[:state] if params[:state]
    respond_to do |format|
      format.json { render_requests_json }
    end
  end

  def render_requests_json
    rawdata = Hash.new
    rawdata['review'] = @displayed_user.involved_reviews.to_a
    rawdata['new'] = @displayed_user.incoming_requests.to_a
    rawdata['declined'] = @displayed_user.declined_requests.to_a
    rawdata['patchinfos'] = @displayed_user.involved_patchinfos.to_a
    render json: Yajl::Encoder.encode(rawdata)
  end

  def save
    if User.current.is_admin?
      user = User.find_by_login!(params[:user])
    else
      user = User.current
      if user.login != params[:user]
        flash[:error] = "Can't edit #{params[:user]}"
        redirect_to(:back) and return
      end
    end
    user.realname = params[:realname]
    user.email = params[:email]
    if User.current.is_admin?
      user.state = User.states[params[:state]] if params[:state]
      user.update_globalroles([params[:globalrole]]) if params[:globalrole]
    end
    user.save!

    flash[:success] = "User data for user '#{user.login}' successfully updated."
    redirect_back_or_to :action => 'show', user: user
  end

  def edit
    @roles = Role.global_roles
    @states = %w(confirmed unconfirmed deleted locked)
  end

  def delete
    u = User.find_by_login(params[:user])
    u.state = User.states['deleted']
    u.save
    redirect_back_or_to :action => 'show', user: u
  end

  def confirm
    u = User.find_by_login(params[:user])
    u.state = User.states['confirmed']
    u.save
    redirect_back_or_to :action => 'show', user: u
  end

  def lock
    u = User.find_by_login(params[:user])
    u.state = User.states['locked']
    redirect_back_or_to :action => 'show', user: u
    u.save
  end

  def admin
    u = User.find_by_login(params[:user])
    u.update_globalroles(%w(Admin))
    redirect_back_or_to :action => 'show', user: u
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

  def user_icon
    required_parameters :icon
    params[:user] = params[:icon].gsub(/.png$/,'')
    icon
  end

  def icon
    required_parameters :user
    user = User.find_by_login! params[:user]
    size = params[:size].to_i || '20'
    content = user.gravatar_image(size)

    if content == :none
      redirect_to ActionController::Base.helpers.asset_path('default_face.png')
      return
    end

    expires_in 5.hours, public: true
    if stale?(etag: Digest::MD5.hexdigest(content))
      render text: content, layout: false, content_type: 'image/png'
    end
  end

  def register
    opts = { :login => params[:login],
             :email => params[:email],
             :realname => params[:realname],
             :password => params[:password],
             :state => params[:state] }
    begin
      UnregisteredUser.register(opts)
    rescue APIException => e
      flash[:error] = e.message
      redirect_back_or_to :controller => 'main', :action => 'index' and return
    end

    flash[:success] = "The account '#{params[:login]}' is now active."

    if User.current.is_admin?
      redirect_to :controller => :configuration, :action => :users
    else
      session[:login] = opts[:login]
      session[:password] = opts[:password]
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
      redirect_to :action => :show, user: User.current
      return
    end

    user = User.current
    user.update_password params[:new_password]
    user.save!

    session[:password] = params[:new_password]
    flash[:success] = 'Your password has been changed successfully.'
    redirect_to :action => :show, user: User.current
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
