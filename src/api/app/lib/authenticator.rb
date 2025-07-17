require 'api_error'

class Authenticator
  class AuthenticationRequiredError < APIError
    setup 401, 'Authentication required'
  end

  class InactiveUserError < APIError
    setup 403, 'User is registered but not in confirmed state. Your account is a registered account, but it is in a not active state.'
  end

  class UnconfirmedUserError < APIError
    setup 403, 'User is registered but not yet approved. Your account is a registered account, but it is not yet approved for the OBS by admin.'
  end

  attr_reader :request, :session, :user_permissions, :http_user

  def initialize(request, session, response)
    @response = response
    @request = request
    @session = session
    @http_user = nil
    @user_permissions = nil
  end

  def extract_user
    # Each request starts out with the nobody user set.
    @http_user = User.find_nobody!

    if ::Configuration.proxy_auth_mode_enabled?
      extract_proxy_user
    elsif session[:login]
      @http_user = User.find_by!(login: session[:login])
    else
      extract_basic_auth_user
    end

    check_extracted_user
    @user_permissions = Suse::Permission.new(@http_user)
    User.session = @http_user
    Rails.logger.debug { "User.session set to #{User.possibly_nobody.login}" }
  end

  private

  # sets @http_user if possible
  def extract_proxy_user
    proxy_user = request.env['HTTP_X_USERNAME']

    # we're using a login proxy, there is no need to authenticate the user from the credentials
    # However we have to care for the status of the user that must not be unconfirmed or proxy requested
    if proxy_user
      @http_user = User.find_by_login(proxy_user)

      # If we do not find a User here, we need to create a user and wait for
      # the confirmation by the user and the BS Admin Team.
      unless @http_user
        if ::Configuration.registration == 'deny'
          Rails.logger.debug('No user found in database, creation disabled')
          raise AuthenticationRequiredError, "User '#{proxy_user}' does not exist"
        end

        @http_user = User.create_user_with_fake_pw!(login: proxy_user, state: User.default_user_state)
      end

      @http_user.update_login_values(request.env)
    else
      Rails.logger.error 'No X-username header was sent by login proxy!'
    end
  end

  # sets @http_user if possible
  def extract_basic_auth_user
    authorization = authorization_infos
    # privacy! logger.debug( "AUTH: #{authorization.inspect}" )
    if authorization
      # logger.debug( "AUTH2: #{authorization}" )
      if authorization[0] == 'Basic'
        login, password = Base64.decode64(authorization[1]).split(':', 2)[0..1]

        # set password to the empty string in case no password is transmitted in the auth string
        password ||= ''

        @http_user = User.find_with_credentials(login, password) if login && password
      else
        Rails.logger.debug { "Unsupported authentication string '#{authorization[0]}' received." }
      end
    else
      Rails.logger.debug 'No authentication string was received.'
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def check_extracted_user
    if ::Configuration.anonymous
      return if @http_user.nobody?
      raise UnconfirmedUserError if @http_user.state == 'unconfirmed'
      raise InactiveUserError if @http_user.state != 'confirmed'
    else
      # we allow people to view the main page and to login...
      return if request.controller_class == Webui::MainController
      return if request.controller_class == Webui::SessionController
      raise AuthenticationRequiredError if @http_user.nobody?
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def authorization_infos
    # 1. try to get it where mod_rewrite might have put it
    # 2. for Apache/mod_fastcgi with -pass-header Authorization
    # 3. regular location
    %w[X-HTTP_AUTHORIZATION Authorization HTTP_AUTHORIZATION].each do |header|
      return request.env[header].to_s.split if request.env.key?(header)
    end
    nil
  end
end
