class Webui::SessionController < Webui::WebuiController
  before_action :kerberos_auth, only: [:new]

  skip_before_action :check_anonymous, only: [:create]

  def new; end

  def create
    user = User.find_with_credentials(params[:username], params[:password])

    if user && !user.is_active?
      redirect_to(root_path, error: 'Your account is disabled. Please contact the administrator for details.')
      return
    end

    unless user
      redirect_to(session_new_path, error: 'Authentication failed')
      return
    end

    Rails.logger.debug "Authenticated as user '#{user.try(:login)}'"

    session[:login] = user.login
    User.current = user

    if request.referer && request.referer.end_with?(session_new_path)
      redirect_to user_show_path(User.current)
    else
      redirect_back(fallback_location: root_path)
    end
  end

  def destroy
    logger.info "Logging out: #{session[:login]}"
    reset_session
    User.current = nil
    if CONFIG['proxy_auth_mode'] == :on
      redirect_to CONFIG['proxy_auth_logout_page']
    else
      redirect_back(fallback_location: root_path)
    end
  end
end
