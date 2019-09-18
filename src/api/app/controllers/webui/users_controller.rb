class Webui::UsersController < Webui::WebuiController
  before_action :require_login, only: [:index, :edit, :destroy, :update]
  before_action :require_admin, only: [:index, :edit, :destroy]
  before_action :get_displayed_user, only: [:show, :edit]

  def index
    respond_to do |format|
      format.html
      format.json { render json: UserConfigurationDatatable.new(params, view_context: view_context) }
    end
    # TODO: Remove the statement after migration is finished
    switch_to_webui2
  end

  def show
    @iprojects = @displayed_user.involved_projects.pluck(:name, :title)
    @ipackages = @displayed_user.involved_packages.joins(:project).pluck(:name, 'projects.name as pname')
    @owned = @displayed_user.owned_packages
    @groups = @displayed_user.groups
    @role_titles = @displayed_user.roles.global.pluck(:title)
    @account_edit_link = CONFIG['proxy_auth_account_page']

    return unless switch_to_webui2 && (CONFIG['contribution_graph'] != :off)

    @last_day = Time.zone.today

    @first_day = @last_day - 52.weeks
    # move back to the monday before (make it up to 53 weeks)
    @first_day -= (@first_day.cwday - 1)

    @activity_hash = User::Contributions.new(@displayed_user, @first_day).activity_hash
  end

  def new
    @pagetitle = params[:pagetitle] || 'Sign up'
    @submit_btn_text = params[:submit_btn_text] || 'Sign up'
    switch_to_webui2
  end

  def create
    begin
      UnregisteredUser.register(opts)
    rescue APIError => e
      flash[:error] = e.message
      redirect_back(fallback_location: root_path)
      return
    end

    flash[:success] = "The account '#{params[:login]}' is now active."

    if User.admin_session?
      redirect_to users_path
    else
      session[:login] = opts[:login]
      User.session = User.find_by!(login: session[:login])
      if User.session!.home_project
        redirect_to project_show_path(User.session!.home_project)
      else
        redirect_to root_path
      end
    end
  end

  def edit
    switch_to_webui2
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

  def update
    @displayed_user = User.find_by_login!(params[:user][:login])

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

  private

  def opts
    {
      realname: params[:realname], login: params[:login], state: params[:state],
      password: params[:password], password_confirmation: params[:password_confirmation],
      email: params[:email]
    }
  end

  # TODO
  # Remove the method WebuiController#check_displayed_user
  # as soon as we migrate all CRUD methods from UserController to here
  # rubocop:disable Naming/AccessorMethodName
  def get_displayed_user
    begin
      @displayed_user = User.find_by_login!(params[:login])
    rescue NotFoundError
      # admins can see deleted users
      @displayed_user = User.find_by_login(params[:login]) if User.admin_session?
      redirect_back(fallback_location: root_path, error: "User not found #{params[:login]}") unless @displayed_user
    end
    @is_displayed_user = (User.session == @displayed_user)
  end
  # rubocop:enable Naming/AccessorMethodName
end
