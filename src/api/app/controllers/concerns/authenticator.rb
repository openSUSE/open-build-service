module Authenticator # rubocop:disable Metrics/ModuleLength
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
    # An explicitly presented API token wins over every other credential:
    # it is the only credential type meant for programmatic access.
    if authorization_headers[0]&.casecmp?('bearer')
      # A bare `Bearer` with no token is still a presented credential:
      # reject it instead of falling through to session or Basic auth.
      authenticate_with_api_token(bearer_token_string)
      return
    end

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
        if request.path == root_path
          flash.now[:error] = error_message
        else
          redirect_to root_path, error: error_message
        end
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

  # Authenticates a general API token (Token::APIToken) from an
  # `Authorization: Bearer <token>` header. A presented-but-invalid token
  # is a 401, never a silent fallthrough to anonymous: the client must know
  # its credential was rejected rather than keep working with no rights.
  def authenticate_with_api_token(bearer)
    token = bearer.present? ? Token::APIToken.authenticate(bearer) : nil

    if token
      User.session = token.executor
      Rails.logger.debug { "User.session set to #{User.possibly_nobody.login} via API token" }
    else
      set_anonymous_user
      render_error status: 401, errorcode: 'invalid_token',
                   message: 'The API token is invalid, expired, or disabled.'
    end
  end

  def bearer_token_string
    return unless authorization_headers[0]&.casecmp?('bearer')

    authorization_headers[1].presence
  end

  # Whether the current request presented a Bearer credential
  # (`Authorization: Bearer <token>`). Used to refuse operations that
  # must not be performed with a token, such as minting new tokens.
  def authenticated_with_api_token?
    authorization_headers[0]&.casecmp?('bearer')
  end

  # In proxy_auth_mode there is no need to authenticate the user from the credentials, the proxy did that.
  # If the proxy passes the X_USERNAME header we just find_or_create the User.
  def find_or_create_proxy_user
    return unless request.env['HTTP_X_USERNAME']

    user = User.for_ichain_username(request.env['HTTP_X_USERNAME'],
                                    { email: request.env['HTTP_X_EMAIL'],
                                      firstname: request.env['HTTP_X_FIRSTNAME'],
                                      lastname: request.env['HTTP_X_LASTNAME'] })
    raise RegistrationDisabledError unless user

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
end
