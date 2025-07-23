class Webui::SessionController < Webui::WebuiController
  before_action :authenticate_user, only: [:create]
  before_action :check_user_active, only: [:create]

  skip_before_action :check_anonymous, only: [:create]

  def new; end

  def create
    session[:login] = @user.login
    User.session = @user

    RabbitmqBus.send_to_bus('metrics', 'login,access_point=webui value=1')

    redirect_on_login
  end

  def reset
    reset_session
    User.session = nil

    RabbitmqBus.send_to_bus('metrics', 'logout,access_point=webui value=1')

    redirect_on_logout
  end

  private

  def check_user_active
    return if @user.active?

    RabbitmqBus.send_to_bus('metrics', 'login,access_point=webui,failure=disabled value=1')
    redirect_to(root_path, error: 'Your account is disabled. Please contact the administrator for details.')
  end

  def authenticate_user
    @user = User.find_with_credentials(params.fetch(:username, ''), params.fetch(:password, ''))

    return if @user

    RabbitmqBus.send_to_bus('metrics', 'login,access_point=webui,failure=unauthenticated value=1')
    redirect_to(new_session_path, error: 'Authentication failed')
  end

  def redirect_on_login
    if referer_was_login?
      redirect_to user_path(User.session)
    else
      redirect_back_or_to root_path
    end
  end

  def redirect_on_logout
    if ::Configuration.anonymous
      redirect_back_or_to root_path
    else
      redirect_to root_path
    end
  end

  def referer_was_login?
    request.referer && request.referer.end_with?(new_session_path)
  end
end
