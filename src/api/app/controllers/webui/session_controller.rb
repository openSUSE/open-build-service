class Webui::SessionController < Webui::WebuiController
  skip_before_action :extract_user
  def new; end

  def create
    user = User.find_with_credentials(params.fetch(:username, ''), params.fetch(:password, ''))

    raise AuthenticationFailed unless user

    session[:login] = user.login
    redirect_on_login
  end

  def reset
    reset_session

    RabbitmqBus.send_to_bus('metrics', 'logout,access_point=webui value=1')

    redirect_on_logout
  end

  private

  def redirect_on_login
    if referer_was_login?
      redirect_to user_path(session[:login])
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
