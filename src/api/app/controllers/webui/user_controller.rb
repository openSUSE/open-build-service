class Webui::UserController < Webui::WebuiController
  before_action :check_display_user, only: [:show, :edit, :list_my]
  before_action :require_login, only: [:edit, :save, :index, :update, :delete]
  before_action :require_admin, only: [:edit, :index, :update, :delete]
  before_action :kerberos_auth, only: [:login]

  skip_before_action :check_anonymous, only: [:do_login]

  def index
    @users = User.all_without_nobody.includes(:owner).select(:id, :login, :email, :state, :realname, :owner_id, :updated_at)
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

  def login; end

  def do_login
    user = User.find_with_credentials(params[:username], params[:password])

    if user && !user.is_active?
      redirect_to(root_path, error: 'Your account is disabled. Please contact the administrator for details.')
      return
    end

    unless user
      redirect_to(user_login_path, error: 'Authentication failed')
      return
    end

    Rails.logger.debug "Authenticated as user '#{user.try(:login)}'"

    session[:login] = user.login
    User.current = user

    if request.referer && request.referer.end_with?('/user/login')
      redirect_to user_show_path(User.current)
    else
      redirect_back(fallback_location: root_path)
    end
  end

  def show
    @iprojects = @displayed_user.involved_projects.pluck(:name, :title)
    @ipackages = @displayed_user.involved_packages.joins(:project).pluck(:name, 'projects.name as pname')
    @owned = @displayed_user.owned_packages
    @groups = @displayed_user.groups
    @role_titles = @displayed_user.roles.global.pluck(:title)

    return unless User.current == @displayed_user
    @is_displayed_user = User.current == @displayed_user
    @patchinfos = @displayed_user.involved_patchinfos
    @account_edit_link = CONFIG['proxy_auth_account_page']
  end

  def home
    if params[:user].present?
      redirect_to action: :show, user: params[:user]
    else
      redirect_to action: :show, user: User.current
    end
  end

  def save
    @displayed_user = User.find_by_login(params[:user][:login])

    unless User.current.is_admin?
      if User.current != @displayed_user || !@configuration.accounts_editable?
        flash[:error] = "Can't edit #{@displayed_user.login}"
        redirect_back(fallback_location: root_path)
        return
      end
    end

    if @configuration.accounts_editable?
      @displayed_user.assign_attributes(params[:user].slice(:realname, :email).permit!)
    end

    if User.current.is_admin?
      @displayed_user.assign_attributes(params[:user].slice(:state).permit!)
      @displayed_user.update_globalroles(Role.global.where(id: params[:user][:role_ids])) unless params[:user][:role_ids].nil?
    end

    begin
      @displayed_user.save!
      flash[:success] = "User data for user '#{@displayed_user.login}' successfully updated."
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = "Couldn't update user: #{e.message}."
    end

    redirect_back(fallback_location: { action: 'show', user: @displayed_user })
  end

  def edit; end

  def update
    other_user = User.find_by(login: params[:user])
    unless other_user
      redirect_to(users_path, error: "Couldn't find user '#{params[:user]}'.")
      return
    end

    other_user.update_attributes(state: params[:state])
    other_user.add_globalrole(Role.where(title: 'Admin')) if params[:make_admin]
    if other_user.save
      flash[:notice] = "Updated user '#{other_user}'."
    else
      flash[:error] = "Updating user '#{other_user}' failed: #{other_user.errors.full_messages.to_sentence}"
    end
    redirect_back(fallback_location: user_show_path(other_user))
  end

  def delete
    other_user = User.find_by(login: params[:user])
    other_user.update_attributes(state: 'deleted')
    if other_user.save
      flash[:notice] = "Marked user '#{other_user}' as deleted."
    else
      flash[:error] = "Marking user '#{other_user}' as deleted failed: #{other_user.errors.full_messages.to_sentence}"
    end
    redirect_to(users_path)
  end

  def save_dialog
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
    render(body: content, layout: false, content_type: 'image/png') if stale?(etag: Digest::MD5.hexdigest(content))
  end

  def register
    opts = { realname: params[:realname], login: params[:login], state: params[:state],
             password: params[:password], password_confirmation: params[:password_confirmation],
             email: params[:email] }

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

  def register_user; end

  def password_dialog
    render_dialog
  end

  def change_password
    unless @configuration.passwords_changable?
      flash[:error] = "You're not authorized to change your password."
      redirect_back fallback_location: root_path
      return
    end

    user = User.current

    if user.authenticate(params[:password])
      user.password = params[:new_password]
      user.password_confirmation = params[:repeat_password]

      if user.save
        flash[:notice] = 'Your password has been changed successfully.'
        redirect_to action: :show, user: user
      else
        flash[:error] = "The password could not be changed. #{user.errors.full_messages.to_sentence}"
        redirect_back fallback_location: root_path
      end
    else
      flash[:error] = 'The value of current password does not match your current password. Please enter the password and try again.'
      redirect_back fallback_location: root_path
      return
    end
  end

  def autocomplete
    required_parameters :term
    render json: list_users(params[:term])
  end

  def tokens
    required_parameters :q
    render json: list_users(params[:q], true)
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
