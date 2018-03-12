class Webui::UserController < Webui::WebuiController
  before_action :check_display_user, only: [:show, :edit, :list_my]
  before_action :require_login, only: [:edit, :save, :index, :update, :delete]
  before_action :require_admin, only: [:edit, :index, :update, :delete]

  def index
    @users = User.all_without_nobody.includes(:owner).
             select(:id, :login, :email, :state, :realname, :owner_id, :updated_at, :ignore_auth_services)
  end

  def show
    @iprojects = @displayed_user.involved_projects.pluck(:name, :title)
    @ipackages = @displayed_user.involved_packages.joins(:project).pluck(:name, 'projects.name as pname')
    @owned = @displayed_user.owned_packages
    @groups = @displayed_user.groups
    @role_titles = @displayed_user.roles.global.pluck(:title)
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
      if User.current != @displayed_user || !@configuration.accounts_editable?(@displayed_user)
        flash[:error] = "Can't edit #{@displayed_user.login}"
        redirect_back(fallback_location: root_path)
        return
      end
    end

    if @configuration.accounts_editable?(@displayed_user)
      @displayed_user.assign_attributes(params[:user].slice(:realname, :email).permit!)
    end

    if User.current.is_admin?
      @displayed_user.assign_attributes(params[:user].slice(:state, :ignore_auth_services).permit!)
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
    other_user = User.find_by(login: user_params[:login])
    unless other_user
      redirect_to(users_path, error: "Couldn't find user '#{user_params[:login]}'.")
      return
    end
    other_user.update(user_params.slice(:state, :ignore_auth_services))
    other_user.add_globalrole(Role.where(title: 'Admin')) if user_params[:make_admin]
    if other_user.save
      flash[:notice] = "Updated user '#{other_user}'."
    else
      flash[:error] = "Updating user '#{other_user}' failed: #{other_user.errors.full_messages.to_sentence}"
    end
    redirect_back(fallback_location: user_show_path(other_user))
  end

  def delete
    other_user = User.find_by(login: user_params[:login])
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

  def icon
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
    user = User.current

    unless @configuration.passwords_changable?(user)
      flash[:error] = "You're not authorized to change your password."
      redirect_back fallback_location: root_path
      return
    end

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
    render json: User.autocomplete_login(params[:term])
  end

  def tokens
    required_parameters :q
    render json: User.autocomplete_token(params[:q])
  end

  private

  def user_params
    params.require(:user).permit(:login, :state, :ignore_auth_services, :make_admin)
  end
end
