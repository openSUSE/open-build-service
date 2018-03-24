class Webui::SessionController < Webui::WebuiController
  before_action :kerberos_auth, only: [:new]

  skip_before_action :check_anonymous, only: [:create]

  def new; end

  def create
    user = User.find_with_credentials(params[:username], params[:password])

    unless user
      redirect_to(session_new_path, error: 'Authentication failed')
      return
    end

    unless user.is_active?
      redirect_to(root_path, error: 'Your account is disabled. Please contact the administrator for details.')
      return
    end

    User.current = user
    session[:login] = user.login
    Rails.logger.debug "Authenticated as user '#{user.login}'"

    redirect_on_login
  end

  def destroy
    Rails.logger.info "Logging out: #{session[:login]}"

    reset_session
    User.current = nil

    redirect_on_logout
  end

  private

  def redirect_on_login
    if referer_was_login?
      redirect_to user_show_path(User.current)
    else
      redirect_back(fallback_location: root_path)
    end
  end

  def redirect_on_logout
    if CONFIG['proxy_auth_mode'] == :on
      redirect_to CONFIG['proxy_auth_logout_page']
    else
      redirect_back(fallback_location: root_path)
    end
  end

  def referer_was_login?
    request.referer && request.referer.end_with?(session_new_path)
  end
end
