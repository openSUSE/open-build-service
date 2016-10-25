require 'base64'
require 'event'

class Webui::UserController < Webui::WebuiController
  before_action :check_display_user, only: [:show, :edit, :requests, :list_my, :delete, :save, :confirm, :admin, :lock]
  before_action :require_login, only: [:edit, :save, :notifications, :update_notifications, :index]
  before_action :require_admin, only: [:edit, :delete, :lock, :confirm, :admin, :index]

  skip_before_action :check_anonymous, only: [:do_login]

  def index
    @users = User.all_without_nobody
  end

  def logout
    logger.info "Logging out: #{session[:login]}"
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
    user = User.find_with_credentials(params[:username], params[:password])

    if user && !user.is_active?
      redirect_to(root_path, error: "Your account is disabled. Please contact the adminsitrator for details.")
      return
    end

    unless user
      redirect_to(user_login_path, error: 'Authentication failed')
      return
    end

    Rails.logger.debug "Authentificated user '#{user.try(:login)}'"

    session[:login] = user.login
    User.current = user

    if request.referer.end_with?("/user/login")
      redirect_to home_path
    else
      redirect_back(fallback_location: root_path)
    end
  end

  def show
    @iprojects = @displayed_user.involved_projects.pluck(:name, :title)
    @ipackages = @displayed_user.involved_packages.joins(:project).pluck(:name, 'projects.name as pname')
    @owned = @displayed_user.owned_packages

    if User.current == @displayed_user
        @reviews = @displayed_user.involved_reviews
        @patchinfos = @displayed_user.involved_patchinfos
        @requests_in = @displayed_user.incoming_requests
        @requests_out = @displayed_user.outgoing_requests
        @declined_requests = @displayed_user.declined_requests
        @user_have_requests = @displayed_user.requests?
    end
  end

  def home
    if params[:user].present?
      redirect_to action: :show, user: params[:user]
    else
      redirect_to action: :show, user: User.current
    end
  end

  # Request from the user
  def requests
    sortable_fields = {
        0 => :created_at,
        3 => :creator,
        5 => :priority
      }
    sorting_field = sortable_fields[params['order[0][column]'].to_i]
    sorting_field ||= :created_at
    sorting_dir = params['order[0][dir]'].try(:to_sym)
    sorting_dir = :asc unless ["asc", "desc"].include?(params['order[0][dir]'])
    search = params[:search] ? params[:search].permit![:value] : ""
    request_methods = {
      'all_requests_table'      => :requests,
      'requests_out_table'      => :outgoing_requests,
      'requests_declined_table' => :declined_requests
    }
    request_method = request_methods[params[:dataTableId]] || :requests
    @requests = @displayed_user.send(request_method, search)
    @requests_count = @requests.count
    @requests = @requests.offset(params[:start].to_i).limit(params[:length].to_i).reorder(sorting_field => sorting_dir)
    respond_to do |format|
      # For jquery dataTable
      format.json {
        render_json_response_for_dataTable(
          draw: params[:draw].to_i + 1,
          total_records_count: @displayed_user.send(request_method).count,
          total_filtered_records_count: @requests_count,
          records: @requests.includes(:bs_request_actions)
        ) do |request|
          render_to_string(partial: "shared/single_request.json", locals: { req: request, no_target: true, hide_state: true }).to_s.split(',')
        end
      }
    end
  end

  def save
    unless User.current.is_admin?
      if User.current != @displayed_user
        flash[:error] = "Can't edit #{@displayed_user.login}"
        redirect_back(fallback_location: root_path) && return
      end
    end
    @displayed_user.realname = params[:realname]
    @displayed_user.email = params[:email]
    if User.current.is_admin?
      @displayed_user.state = params[:state] if params[:state]
      # FIXME: If we ever have more than one global this, and the view, has to be fixed
      @displayed_user.update_globalroles([params[:globalrole]].compact)
    end

    begin
      @displayed_user.save!
      flash[:success] = "User data for user '#{@displayed_user.login}' successfully updated."
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = "Couldn't update user: #{e.message}."
    end

    redirect_back(fallback_location: { action: 'show', user: @displayed_user })
  end

  def edit
    @roles = Role.global_roles
    @states = %w(confirmed unconfirmed deleted locked)
  end

  def delete
    @displayed_user.state = 'deleted'
    @displayed_user.save
    redirect_back(fallback_location: { action: 'show', user: @displayed_user })
  end

  def confirm
    @displayed_user.state = 'confirmed'
    @displayed_user.save
    redirect_back(fallback_location: { action: 'show', user: @displayed_user })
  end

  def lock
    @displayed_user.state = 'locked'
    @displayed_user.save
    redirect_back(fallback_location: { action: 'show', user: @displayed_user })
  end

  def admin
    @displayed_user.update_globalroles(%w(Admin))
    @displayed_user.save
    redirect_back(fallback_location: { action: 'show', user: @displayed_user })
  end

  def save_dialog
    @roles = Role.global_roles
    render_dialog
  end

  def user_icon
    required_parameters :icon
    params[:user] = params[:icon].gsub(/.png$/, '')
    icon
  end

  def icon
    required_parameters :user
    size = params[:size].to_i || '20'
    user = User.find_by_login(params[:user])
    if user.nil? || (content = user.gravatar_image(size)) == :none
      redirect_to ActionController::Base.helpers.asset_path('default_face.png')
      return
    end

    expires_in 5.hours, public: true
    if stale?(etag: Digest::MD5.hexdigest(content))
      render body: content, layout: false, content_type: 'image/png'
    end
  end

  def register
    opts = { login:    params[:login],
             email:    params[:email],
             realname: params[:realname],
             password: params[:password],
             state:    params[:state] }
    begin
      UnregisteredUser.register(opts)
    rescue APIException => e
      flash[:error] = e.message
      redirect_back(fallback_location: root_path)
      return
    end

    flash[:success] = "The account '#{params[:login]}' is now active."

    if User.current.is_admin?
      redirect_to controller: :user, action: :index
    else
      session[:login] = opts[:login]
      User.current = User.find_by_login(session[:login])
      if User.current.home_project
        redirect_to project_show_path(User.current.home_project)
      else
        redirect_to root_path
      end
    end
  end

  def register_user
  end

  def password_dialog
    render_dialog
  end

  def change_password
    # check the valid of the params
    unless User.current.password_equals?(params[:password])
      errmsg = 'The value of current password does not match your current password. Please enter the password and try again.'
    end
    if params[:new_password] != params[:repeat_password]
      errmsg = 'The passwords do not match, please try again.'
    end
    if params[:password] == params[:new_password]
      errmsg = 'The new password is the same as your current password. Please enter a new password.'
    end
    if errmsg
      flash[:error] = errmsg
      redirect_to action: :show, user: User.current
      return
    end

    user = User.current
    user.update_password params[:new_password]
    user.save!

    flash[:success] = 'Your password has been changed successfully.'
    redirect_to action: :show, user: User.current
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
    @user = User.current
    @groups = User.current.groups_users
    @notifications = Event::Base.notification_events
  end

  def update_notifications
    User.current.groups_users.each do |gu|
      gu.email = params[gu.group.title] == '1'
      gu.save
    end

    User.current.update_notifications(params)

    flash[:notice] = 'Notifications settings updated'
    redirect_to action: :notifications
  end

  protected

  def list_users(prefix = nil, hash = nil)
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
