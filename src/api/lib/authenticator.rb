if CONFIG['kerberos_service_principal']
  require_dependency 'gssapi'
end

class Authenticator
  class AuthenticationRequiredError < APIException
    setup 401, "Authentication required"
  end

  class AnonymousUser < APIException
    setup 401
  end

  class NoPublicAccessError < APIException
    setup 401
  end

  class InactiveUserError < APIException
    setup 403
  end

  class UnconfirmedUserError < APIException
    setup 403
  end

  class AdminUserRequiredError < APIException
    setup('put_request_no_permission', 403)
  end

  attr_reader :request, :session, :user_permissions, :http_user

  def initialize(request, session, response)
    @response = response
    @request = request
    @session = session
    @http_user = nil
    @user_permissions = nil
  end

  def proxy_mode?
    CONFIG['proxy_auth_mode'] == :on || CONFIG['ichain_mode'] == :on
  end

  def extract_user
    if proxy_mode?
      extract_proxy_user
    else
      extract_auth_user
      @http_user = User.find_with_credentials @login, @passwd if @login && @passwd
    end

    if !@http_user && session[:login]
      @http_user = User.find_by_login session[:login]
    end

    check_extracted_user
  end

  def extract_user_public
    if ::Configuration.anonymous
      load_nobody
    else
      Rails.logger.error 'No public access is configured'
      raise NoPublicAccessError.new 'No public access is configured'
    end
  end

  def require_login
    # we allow anonymous user only for rare special operations (if configured) but we require
    # a valid account for all other operations.
    # For this rare special operations we simply skip the require login before filter!
    # At the moment these operations are the /public, /trigger and /about controller actions.
    raise AnonymousUser.new 'Anonymous user is not allowed here - please login' if !User.current || User.current.is_nobody?
  end

  def require_admin
    Rails.logger.debug "Checking for  Admin role for user #{@http_user.login}"
    unless @http_user.is_admin?
      Rails.logger.debug "not granted!"
      raise AdminUserRequiredError.new('Requires admin privileges')
    end
    true
  end

  private

  def initialize_krb_session
    principal = CONFIG['kerberos_service_principal']

    unless CONFIG['kerberos_realm']
      CONFIG['kerberos_realm'] = principal.rpartition("@")[2]
    end

    krb = GSSAPI::Simple.new(
      principal.partition("/")[2].rpartition("@")[0],
      principal.partition("/")[0],
      CONFIG['kerberos_keytab'] || "/etc/krb5.keytab"
    )
    krb.acquire_credentials

    return krb
  end

  def extract_krb_user(authorization)
    unless authorization[1]
      Rails.logger.debug "Didn't receive any negotiation data."
      @response.headers["WWW-Authenticate"] = authorization.join(' ')
      raise AuthenticationRequiredError.new "GSSAPI negotiation failed."
    end

    begin
      krb = initialize_krb_session

      begin
        tok = krb.accept_context(Base64.strict_decode64(authorization[1]))
      rescue GSSAPI::GssApiError
        @response.headers["WWW-Authenticate"] = authorization.join(' ')
        raise AuthenticationRequiredError.new "Received invalid GSSAPI context."
      end

      unless krb.display_name.match("@#{CONFIG['kerberos_realm']}$")
        @response.headers["WWW-Authenticate"] = authorization.join(' ')
        raise AuthenticationRequiredError.new "User authenticated in wrong Kerberos realm."
      end

      unless tok == true
        tok = Base64.strict_encode64(tok)
        @response.headers["WWW-Authenticate"] = "Negotiate #{tok}"
      end

      @login = krb.display_name.partition("@")[0]
      @http_user = User.find_by_login @login
      raise AuthenticationRequiredError.new "User '#{@login}' has no account on the server." unless @http_user
    rescue GSSAPI::GssApiError => err
      raise AuthenticationRequiredError.new, "Received a GSSAPI exception; #{err.message}."
    end
  end

  def extract_basic_user(authorization)
    @login, @passwd = Base64.decode64(authorization[1]).split(':', 2)[0..1]

    # set password to the empty string in case no password is transmitted in the auth string
    @passwd ||= ""
  end

  def extract_proxy_user
    proxy_user = request.env['HTTP_X_USERNAME']
    if proxy_user
      Rails.logger.info "iChain user extracted from header: #{proxy_user}"
    end

    # we're using a login proxy, there is no need to authenticate the user from the credentials
    # However we have to care for the status of the user that must not be unconfirmed or proxy requested
    if proxy_user
      @http_user = User.find_by_login proxy_user

      # If we do not find a User here, we need to create a user and wait for
      # the confirmation by the user and the BS Admin Team.
      unless @http_user
        if ::Configuration.registration == "deny"
          Rails.logger.debug("No user found in database, creation disabled")
          raise AuthenticationRequiredError.new "User '#{login}' does not exist"
        end
        # Generate and store a fake pw in the OBS DB that no-one knows
        # FIXME: we should allow NULL passwords in DB, but that needs user management cleanup
        chars = ["A".."Z", "a".."z", "0".."9"].collect(&:to_a).join
        fakepw = (1..24).collect { chars[rand(chars.size)] }.pack("a" * 24)
        @http_user = User.new(
          login: proxy_user,
          state: User.default_user_state,
          password: fakepw)
      end

      # update user data from login proxy headers
      @http_user.update_user_info_from_proxy_env(request.env) if @http_user
    else
      Rails.logger.error "No X-username header from login proxy! Are we really using an authentification proxy?"
    end
  end

  def extract_auth_user
    authorization = authorization_infos

    # privacy! logger.debug( "AUTH: #{authorization.inspect}" )
    if authorization
      # logger.debug( "AUTH2: #{authorization}" )
      if authorization[0] == "Basic"
        extract_basic_user authorization
      elsif authorization[0] == "Negotiate" && CONFIG['kerberos_service_principal']
        extract_krb_user authorization
      else
        Rails.logger.debug "Unsupported authentication string '#{authorization[0]}' received."
      end
    else
      Rails.logger.debug "No authentication string was received."
    end
  end

  def authorization_infos
    # 1. try to get it where mod_rewrite might have put it
    # 2. for Apace/mod_fastcgi with -pass-header Authorization
    # 3. regular location
    %w(X-HTTP_AUTHORIZATION Authorization HTTP_AUTHORIZATION).each do |header|
      if request.env.has_key? header
        return request.env[header].to_s.split
      end
    end
    return
  end

  def check_extracted_user
    unless @http_user
      if @login.blank?
        return true if check_for_anonymous_user
        raise AuthenticationRequiredError.new
      end
      raise AuthenticationRequiredError.new "Unknown user '#{@login}' or invalid password"
    end

    if @http_user.state == 'unconfirmed'
      raise UnconfirmedUserError.new "User is registered but not yet approved. " +
                                         "Your account is a registered account, but it is not yet approved for the OBS by admin."
    end

    User.current = @http_user

    if @http_user.state == 'confirmed'
      Rails.logger.debug "USER found: #{@http_user.login}"
      @user_permissions = Suse::Permission.new(@http_user)
      return true
    end

    raise InactiveUserError.new "User is registered but not in confirmed state. Your account is a registered account, " +
                                "but it is in a not active state."
  end

  def check_for_anonymous_user
    if ::Configuration.anonymous
      # Fixed list of clients which do support the read only mode
      hua = request.env['HTTP_USER_AGENT']
      if hua # ignore our test suite (TODO: we need to fix that)
        load_nobody
        return true
      end
    end
    false
  end

   # to become _public_ special user
  def load_nobody
    @http_user = User.find_nobody!
    User.current = @http_user
    @user_permissions = Suse::Permission.new( User.current )
  end
end
