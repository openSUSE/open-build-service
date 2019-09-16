class Webui::UserController < Webui::WebuiController
  before_action :check_display_user, only: [:list_my]
  before_action :require_login, only: [:save, :update]
  before_action :require_admin, only: [:update]

  def home
    if params[:user].present?
      redirect_to user_path(params[:user])
    else
      redirect_to user_path(User.possibly_nobody)
    end
  end

  def save
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

  def update
    other_user = User.find_by(login: user_params[:login])
    unless other_user
      redirect_to(users_path, error: "Couldn't find user '#{user_params[:login]}'.")
      return
    end
    other_user.update(user_params.slice(:state, :ignore_auth_services))
    other_user.add_globalrole(Role.where(title: 'Admin')) if user_params[:make_admin]
    if other_user.save
      flash[:success] = "Updated user '#{other_user}'."
    else
      flash[:error] = "Updating user '#{other_user}' failed: #{other_user.errors.full_messages.to_sentence}"
    end
    redirect_back(fallback_location: user_path(other_user))
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
    render json: User.autocomplete_login(params[:term])
  end

  def tokens
    render json: User.autocomplete_token(params[:q])
  end

  private

  def user_params
    params.require(:user).permit(:login, :state, :ignore_auth_services, :make_admin)
  end
end
