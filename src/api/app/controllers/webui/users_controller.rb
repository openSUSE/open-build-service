class Webui::UsersController < Webui::WebuiController
  include Webui::NotificationsHandler

  before_action :require_login, except: %i[show new create tokens autocomplete]
  before_action :require_admin, only: %i[index edit destroy]
  before_action :check_displayed_user, only: %i[show edit censor update destroy edit_account]
  before_action :role_titles, only: %i[show edit_account update]
  before_action :account_edit_link, only: %i[show edit_account update]

  after_action :verify_authorized, only: %i[edit destroy update edit_account]

  def index
    respond_to do |format|
      format.html
      format.json { render json: UserConfigurationDatatable.new(params, view_context: view_context) }
    end
  end

  def show
    @groups = @displayed_user.groups.order(:title)
    @involved_items_service = UserService::Involved.new(user: @displayed_user, filters: extract_filter_params, page: params[:page])
    @comments = paged_comments

    return if CONFIG['contribution_graph'] == :off

    @last_day = Time.zone.today

    @first_day = @last_day - 52.weeks
    # move back to the monday before (make it up to 53 weeks)
    @first_day -= (@first_day.cwday - 1)

    @activities_per_year = UserYearlyContribution.new(@displayed_user, @first_day).call
    @date = params[:date]
    @activities_per_day = UserDailyContribution.new(@displayed_user, @date).call
    @current_notification = handle_notification
  end

  def new
    @pagetitle = params[:pagetitle] || 'Sign Up'
    @submit_btn_text = params[:submit_btn_text] || 'Sign Up'
  end

  def edit
    authorize @displayed_user, :update?
  end

  def create
    begin
      UnregisteredUser.register(create_params)
    rescue APIError => e
      flash[:error] = e.message
      redirect_back_or_to root_path
      return
    end

    flash[:success] = "The account '#{params[:login]}' is now active."

    if User.admin_session?
      redirect_to users_path
    else
      session[:login] = create_params[:login]
      User.session = User.find_by!(login: session[:login])
      if User.session.home_project
        redirect_to project_show_path(User.session.home_project)
      else
        redirect_to root_path
      end
    end
  end

  def censor
    authorize @displayed_user, :censor?

    @displayed_user.update(params.require(:user).permit(:censored))

    if @displayed_user.save
      status = @displayed_user.censored ? "censored, they can't comment" : 'allowed to comment again'
      flash[:success] = "User '#{@displayed_user.login}' successfully #{status}."
    else
      flash[:error] = "Couldn't update user: #{@displayed_user.errors.full_messages.to_sentence}."
    end
    redirect_back_or_to user_path(@displayed_user)
  end

  def update
    authorize @displayed_user, :update?

    assign_common_user_attributes
    assign_admin_attributes if User.admin_session?

    respond_to do |format|
      if @displayed_user.save
        message = "User data for user '#{@displayed_user.login}' successfully updated."
        format.html { flash[:success] = message }
        format.js { flash.now[:success] = message }
      else
        message = "Couldn't update user: #{@displayed_user.errors.full_messages.to_sentence}."
        format.html { flash[:error] = message }
        format.js { flash.now[:error] = message }
      end
      redirect_back_or_to user_path(@displayed_user) if request.format.symbol == :html
    end
  end

  def destroy
    authorize @displayed_user, :destroy?

    if @displayed_user.delete!(adminnote: params[:adminnote])
      flash[:success] = "Marked user '#{@displayed_user}' as deleted."
    else
      flash[:error] = "Marking user '#{@displayed_user}' as deleted failed: #{@displayed_user.errors.full_messages.to_sentence}"
    end
    redirect_to(users_path)
  end

  def edit_account
    authorize @displayed_user, :update?

    respond_to do |format|
      format.js
    end
  end

  def autocomplete
    render json: User.autocomplete_login(params[:term])
  end

  def tokens
    render json: User.autocomplete_token(params[:q])
  end

  def change_password
    unless ::Configuration.passwords_changable?
      flash[:error] = "You're not authorized to change your password."
      redirect_back_or_to root_path
      return
    end

    user = User.session

    if user.authenticate(params[:password])
      user.password = params[:new_password]
      user.password_confirmation = params[:repeat_password]

      if user.save
        flash[:success] = 'Your password has been changed successfully.'
        redirect_to action: :show, login: user
      else
        flash[:error] = "The password could not be changed. #{user.errors.full_messages.to_sentence}"
        redirect_back_or_to root_path
      end
    else
      flash[:error] = 'The value of current password does not match your current password. Please enter the password and try again.'
      redirect_back_or_to root_path
      nil
    end
  end

  def rss_secret
    user = User.session

    verb_prefix = user.rss_secret.present? ? 're-' : ''

    user.regenerate_rss_secret
    respond_to do |format|
      format.html { redirect_to my_subscriptions_path, notice: "Successfully #{verb_prefix}generated RSS secret" }
    end
  end

  private

  def extract_filter_params
    params.slice(:search_text, :involved_projects, :involved_packages,
                 :role_maintainer, :role_bugowner, :role_reviewer, :role_downloader, :role_reader, :role_owner)
  end

  def create_params
    {
      realname: params[:realname], login: params[:login], state: params[:state],
      password: params[:password], password_confirmation: params[:password_confirmation],
      email: params[:email]
    }
  end

  def role_titles
    @role_titles = @displayed_user.roles.global.pluck(:title)
  end

  def account_edit_link
    @account_edit_link = CONFIG['proxy_auth_account_page']
  end

  def assign_common_user_attributes
    @displayed_user.assign_attributes(params[:user].slice(:biography, :color_theme, :in_beta).permit!)
    @displayed_user.assign_attributes(params[:user].slice(:realname, :email).permit!) unless @account_edit_link
  end

  def assign_admin_attributes
    @displayed_user.assign_attributes(params[:user].slice(:state, :ignore_auth_services).permit!)
    @displayed_user.update_globalroles(Role.global.where(id: params[:user][:role_ids])) unless params[:user][:role_ids].nil?
  end

  def paged_comments
    return unless Flipper.enabled?(:content_moderation, User.session)
    return unless policy(@displayed_user).comment_index?

    comments = @displayed_user.comments.includes(:project).newest_first
    params[:page] = comments.page(params[:page]).total_pages if comments.page(params[:page]).out_of_range?
    comments.page(params[:page])
  end
end
