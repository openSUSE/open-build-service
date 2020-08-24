class Webui::UsersController < Webui::WebuiController
  before_action :require_login, only: [:index, :edit, :destroy, :update, :change_password]
  before_action :require_admin, only: [:index, :edit, :destroy]
  before_action :check_displayed_user, only: [:show, :edit, :update]

  def index
    respond_to do |format|
      format.html
      format.json { render json: UserConfigurationDatatable.new(params, view_context: view_context) }
    end
  end

  def show
    @iprojects = @displayed_user.involved_projects.pluck(:name, :title)
    @ipackages = @displayed_user.involved_packages.joins(:project).pluck(:name, 'projects.name as pname')
    @owned = @displayed_user.owned_packages
    @groups = @displayed_user.groups
    @role_titles = @displayed_user.roles.global.pluck(:title)
    @account_edit_link = CONFIG['proxy_auth_account_page']

    return if CONFIG['contribution_graph'] == :off

    @last_day = Time.zone.today

    @first_day = @last_day - 52.weeks
    # move back to the monday before (make it up to 53 weeks)
    @first_day -= (@first_day.cwday - 1)

    @activity_hash = User::Contributions.new(@displayed_user, @first_day).activity_hash
  end

  def new
    @pagetitle = params[:pagetitle] || 'Sign up'
    @submit_btn_text = params[:submit_btn_text] || 'Sign up'
  end

  def create
    begin
      UnregisteredUser.register(create_params)
    rescue APIError => e
      flash[:error] = e.message
      redirect_back(fallback_location: root_path)
      return
    end

    flash[:success] = "The account '#{params[:login]}' is now active."

    if User.admin_session?
      redirect_to users_path
    else
      session[:login] = create_params[:login]
      User.session = User.find_by!(login: session[:login])
      if User.session!.home_project
        redirect_to project_show_path(User.session!.home_project)
      else
        redirect_to root_path
      end
    end
  end

  def destroy
    user = User.find_by(login: params[:login])
    if user.delete
      flash[:success] = "Marked user '#{user}' as deleted."
    else
      flash[:error] = "Marking user '#{user}' as deleted failed: #{user.errors.full_messages.to_sentence}"
    end
    redirect_to(users_path)
  end

  def edit; end

  def update
    unless User.admin_session?
      if User.session! != @displayed_user || !@configuration.accounts_editable?(@displayed_user)
        flash[:error] = "Can't edit #{@displayed_user.login}"
        redirect_back(fallback_location: root_path)
        return
      end
    end

    if @configuration.accounts_editable?(@displayed_user)
      @displayed_user.assign_attributes(params[:user].slice(:realname, :email).permit!)
      @displayed_user.toggle(:in_beta) if params[:user][:in_beta]
    end

    if User.admin_session?
      @displayed_user.assign_attributes(params[:user].slice(:state, :ignore_auth_services).permit!)
      @displayed_user.update_globalroles(Role.global.where(id: params[:user][:role_ids])) unless params[:user][:role_ids].nil?
    end

    begin
      @displayed_user.save!
      flash[:success] = "User data for user '#{@displayed_user.login}' successfully updated."
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = "Couldn't update user: #{e.message}."
    end

    redirect_back(fallback_location: user_path(@displayed_user))
  end

  def autocomplete
    render json: User.autocomplete_login(params[:term])
  end

  def tokens
    render json: User.autocomplete_token(params[:q])
  end

  def change_password
    user = User.session!

    unless @configuration.passwords_changable?(user)
      flash[:error] = "You're not authorized to change your password."
      redirect_back fallback_location: root_path
      return
    end

    if user.authenticate(params[:password])
      user.password = params[:new_password]
      user.password_confirmation = params[:repeat_password]

      if user.save
        flash[:success] = 'Your password has been changed successfully.'
        redirect_to action: :show, login: user
      else
        flash[:error] = "The password could not be changed. #{user.errors.full_messages.to_sentence}"
        redirect_back fallback_location: root_path
      end
    else
      flash[:error] = 'The value of current password does not match your current password. Please enter the password and try again.'
      redirect_back fallback_location: root_path
      nil
    end
  end

  private

  def create_params
    {
      realname: params[:realname], login: params[:login], state: params[:state],
      password: params[:password], password_confirmation: params[:password_confirmation],
      email: params[:email]
    }
  end
end
