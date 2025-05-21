class Webui::SessionController < Webui::WebuiController
  before_action :kerberos_auth, only: [:new]

  before_action :session_creator, only: [:create]
  before_action :authenticate, only: [:create]
  before_action :check_user_active, only: [:create]

  skip_before_action :check_anonymous, only: [:create]

  def new; end

  def create
    User.session = @session_creator.user
    session[:login] = @session_creator.user.login
    send_login_information_rabbitmq(:success)
    redirect_on_login
  end

  def destroy
    reset_session
    send_login_information_rabbitmq(:logout)
    User.session = nil
    redirect_on_logout
  end

  private

  def session_creator
    @session_creator = SessionControllerService::SessionCreator.new(params.slice(:username, :password))
  end

  def check_user_active
    return if @session_creator.user.active?

    send_login_information_rabbitmq(:disabled)
    redirect_to(root_path, error: 'Your account is disabled. Please contact the administrator for details.')
  end

  def authenticate
    return if @session_creator.valid? && @session_creator.exist?

    send_login_information_rabbitmq(:unauthenticated)
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
    if ::Configuration.proxy_auth_mode_enabled?
      redirect_to CONFIG['proxy_auth_logout_page']
    elsif ::Configuration.anonymous
      redirect_back_or_to root_path
    else
      redirect_to root_path
    end
  end

  def referer_was_login?
    request.referer && request.referer.end_with?(new_session_path)
  end
end
