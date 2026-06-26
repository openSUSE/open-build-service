module Authenticator
  extend ActiveSupport::Concern

  included do
    before_action :set_anonymous_user
    before_action :extract_user
    before_action :check_user_state
    before_action :check_anonymous_access
    before_action :track_user_login
  end

  def set_anonymous_user
    User.session = User.find_nobody!
  end

  def extract_user
    user = if ::Configuration.proxy_auth_mode_enabled?
             find_or_create_proxy_user
           elsif request.session[:login] # Webui Session Auth
             User.find_by!(login: request.session[:login])
           elsif authorization_headers.present? # API Basic Auth
             basic_auth_info = basic_auth
             User.find_with_credentials(basic_auth_info[:login], basic_auth_info[:password])
           end

    return unless user

    User.session = user
    Rails.logger.debug { "User.session set to #{User.possibly_nobody.login}" }
  end

  def check_user_state
    return unless User.session
    return if User.session.state == 'confirmed'

    error_message = case User.session.state
                    when 'unconfirmed'
                      'Your account is not yet approved. Talk to your OBS Admin.'
                    else
                      'Your account is not active. Talk to your OBS Admin.'
                    end

    error_code = case User.session.state
                 when 'unconfirmed'
                   'unconfirmed_user'
                 else
                   'inactive_user'
                 end

    set_anonymous_user
    reset_session

    respond_to do |format|
      format.html do
        redirect_to root_path, error: error_message
      end
      format.xml do
        render_error status: 403, errorcode: error_code, message: error_message
      end
    end
  end

  def check_anonymous_access
    return if ::Configuration.anonymous

    require_login
  end

  def track_user_login
    return unless User.session

    User.session.mark_login!
  end

  private

  # In proxy_auth_mode there is no need to authenticate the user from the credentials, the proxy did that.
  # If the proxy passes the X_USERNAME header we just find_or_create the User.
  def find_or_create_proxy_user
    return unless request.env['HTTP_X_USERNAME']

    user = User.find_by(login: request.env['HTTP_X_USERNAME'])

    unless user
      raise RegistrationDisabledError if ::Configuration.registration == 'deny'

      user = User.create_user_with_fake_pw!(login: request.env['HTTP_X_USERNAME'], state: User.default_user_state)
    end

    user.update!(user_proxy_information)
    user
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

    "#{request.env['HTTP_X_FIRSTNAME']} #{request.env['HTTP_X_LASTNAME']}".strip.force_encoding('UTF-8')
  end
end
