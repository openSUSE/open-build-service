require 'api_error'

class Authenticator
  attr_reader :request

  def initialize(request)
    @request = request
  end

  def extract_user
    user = if ::Configuration.proxy_auth_mode_enabled?
             extract_proxy_user
           elsif request.session[:login] # Webui Session Auth
             User.find_by!(login: request.session[:login])
           elsif authorization_headers.present? # API Basic Auth
             User.find_with_credentials!(basic_auth[:login], basic_auth[:password])
           end

    user ||= User.find_nobody!

    check_anonymous_access(user)
    check_user_state(user)
    unless user.nobody?
      user.update!(last_logged_in_at: Time.zone.today, login_failure_count: 0)
      Rails.logger.debug { "User.session set to #{user.login}" }
    end
    User.session = user
  end

  private

  # If we are using proxy_auth_mode there is no need to authenticate the user from the credentials, the proxy did that.
  # We just find_or_create the User.
  def extract_proxy_user
    return unless request.env['HTTP_X_USERNAME']

    user = User.find_by(login: request.env['HTTP_X_USERNAME'])

    unless user
      raise ErrRegisterSave, 'Sorry, sign up is disabled' if ::Configuration.registration == 'deny'

      user = User.create_user_with_fake_pw!(login: request.env['HTTP_X_USERNAME'], state: User.default_user_state)
    end

    user.update!(user_proxy_information)
    user
  end

  def check_anonymous_access(user)
    return if ::Configuration.anonymous

    # we allow people to view the main page, login and sign up even if anonymous access is disabled...
    return if request.controller_class == Webui::MainController
    return if request.controller_class == Webui::SessionController
    return if request.controller_class == Webui::UsersController && request.params['action'] == 'create'

    raise AuthenticationRequiredError if user.nobody?
  end

  def check_user_state(user)
    return true if user.nobody?

    raise UnconfirmedUserError if user.state == 'unconfirmed'
    raise InactiveUserError if user.state != 'confirmed'
  end

  def basic_auth
    return {} if authorization_headers.blank?

    login = nil
    password = nil

    if authorization_headers[0] == 'Basic'
      login, password = Base64.decode64(authorization_headers[1]).split(':', 2)[0..1]
    else
      Rails.logger.debug { "Unsupported authentication string '#{authorization_headers[0]}' received." }
    end
    { login: login, password: password }.compact
  end

  def authorization_headers
    # 1. try to get it where mod_rewrite might have put it
    # 2. for Apache/mod_fastcgi with -pass-header Authorization
    # 3. regular location
    %w[X-HTTP_AUTHORIZATION Authorization HTTP_AUTHORIZATION].each do |header|
      return request.env[header].to_s.split if request.env.key?(header)
    end
    Rails.logger.debug 'No authentication header was received.'

    []
  end

  def user_proxy_information
    { email: request.env['HTTP_X_EMAIL'],
      realname: proxy_realname }.compact
  end

  def proxy_realname
    return if request.env['HTTP_X_FIRSTNAME'].blank? && request.env['HTTP_X_LASTNAME'].blank?

    "#{request.env['HTTP_X_FIRSTNAME'].force_encoding('UTF-8')} #{request.env['HTTP_X_LASTNAME'].force_encoding('UTF-8')}"
  end
end
