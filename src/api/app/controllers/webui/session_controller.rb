class Webui::SessionController < Webui::WebuiController
  before_action :kerberos_auth, only: [:new]

  skip_before_action :check_anonymous, only: [:new, :create, :sso, :sso_callback, :sso_confirm, :do_sso_confirm]

  def new
    switch_to_webui2
  end

  def create
    user = User.find_with_credentials(params[:username], params[:password])

    unless user
      RabbitmqBus.send_to_bus('metrics', 'login,access_point=webui,failure=unauthenticated value=1')
      redirect_to(session_new_path, error: 'Authentication failed')
      return
    end

    unless user.is_active?
      RabbitmqBus.send_to_bus('metrics', 'login,access_point=webui,failure=disabled value=1')
      redirect_to(root_path, error: 'Your account is disabled. Please contact the administrator for details.')
      return
    end

    User.session = user
    session[:login] = user.login
    Rails.logger.debug "Authenticated as user '#{user.login}'"
    RabbitmqBus.send_to_bus('metrics', 'login,access_point=webui value=1')

    redirect_on_login
  end

  def destroy
    Rails.logger.info "Logging out: #{session[:login]}"

    reset_session
    RabbitmqBus.send_to_bus('metrics', 'logout,access_point=webui value=1')
    User.session = nil

    redirect_on_logout
  end

  def sso
    switch_to_webui2
  end

  def sso_callback
    @auth_hash = request.env['omniauth.auth']
    user = User.find_with_omniauth(@auth_hash)

    unless user
      session[:auth] = @auth_hash
      redirect_to(sso_confirm_path)
      return
    end

    unless user.is_active?
      RabbitmqBus.send_to_bus('metrics', 'login,access_point=webui,failure=disabled value=1')
      redirect_to(root_path, error: 'Your account is disabled. Please contact the administrator for details.')
      return
    end

    User.session = user
    session[:login] = user.login
    Rails.logger.debug "Authenticated user '#{user.login}'"

    redirect_on_login
  end

  def sso_confirm
    switch_to_webui2
    auth_hash = session[:auth]

    if !auth_hash
      redirect_to sso_path
      return
    end

    # Try to derive a username from the information available,
    # falling back to full name if nothing else works
    @derived_username = auth_hash['info']['username'] ||
                        auth_hash['info']['nickname'] ||
                        auth_hash['info']['email'] ||
                        auth_hash['info']['name']

    # Some providers set username or nickname to an email address
    # Derive the username from the local part of the email address,
    # if possible. The full name with spaces replaced by underscores
    # is the last resort fallback.
    @derived_username = @derived_username.rpartition("@")[0] if @derived_username.include? "@"
    @derived_username = @derived_username.gsub(' ', '_')
  end

  def do_sso_confirm
    required_parameters :login
    auth_hash = session[:auth]

    if !auth_hash
      redirect_to sso_path
      return
    end

    existing_user = User.find_by_login(params[:login])
    if existing_user
      flash[:error] = "Username #{params[:login]} is already taken, choose a different one"
      redirect_to sso_confirm_path
      return
    end

    begin
      user = User.create_with_omniauth(auth_hash, params[:login])
    rescue ActiveRecord::ActiveRecordError
      flash[:error] = "Invalid username, please try a different one"
      redirect_to sso_confirm_path
      return
    end

    unless user
      flash[:error] = "Cannot create user"
      redirect_to root_path
      return
    end

    unless user.is_active?
      RabbitmqBus.send_to_bus('metrics', 'login,access_point=webui,failure=disabled value=1')
      redirect_to(root_path, error: 'Your account needs to be confirmed by the administrator.')
      return
    end

    User.session = user
    session[:login] = user.login
    Rails.logger.debug "Authenticated user '#{user.login}'"

    redirect_on_login
  end


  private

  def redirect_on_login
    if !referer_was_ours?
      redirect_to root_path
    elsif referer_was_login?
      redirect_to user_show_path(User.session!)
    else
      redirect_back(fallback_location: root_path)
    end
  end

  def redirect_on_logout
    if CONFIG['proxy_auth_mode'] == :on
      redirect_to CONFIG['proxy_auth_logout_page']
    else
      redirect_to root_path
    end
  end

  def referer_was_ours?
    return false unless request.referer

    parsed = URI.parse(request.referer)
    parsed.host == request.host and parsed.port == request.port
  end

  def referer_was_login?
    return false unless request.referer

    parsed = URI.parse(request.referer)
    return false unless parsed.host == request.host
    return false unless parsed.port == request.port

    parsed.path == session_new_path or parsed.path.starts_with?(sso_path)
  end
end
