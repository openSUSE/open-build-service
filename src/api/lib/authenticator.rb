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

  attr_reader :request, :session, :auth_method, :user_permissions, :http_user

  def initialize(request, session)
    @request = request
    @session = session
    @http_user = nil
    @user_permissions = nil
  end

  def extract_user
    mode = CONFIG['proxy_auth_mode'] || CONFIG['ichain_mode'] || :basic
    if mode == :on
      extract_proxy_user
    else
      @auth_method = :basic

      extract_basic_auth_user

      @http_user = User.find_with_credentials @login, @passwd if @login
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

  def extract_proxy_user
    @auth_method = :proxy
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

  def extract_basic_auth_user
    authorization = authorization_infos

    # privacy! Rails.logger.debug( "AUTH: #{authorization.inspect}" )

    if authorization && authorization[0] == "Basic"
      # Rails.logger.debug( "AUTH2: #{authorization}" )
      @login, @passwd = Base64.decode64(authorization[1]).split(':', 2)[0..1]

      # set password to the empty string in case no password is transmitted in the auth string
      @passwd ||= ""
    else
      Rails.logger.debug "no authentication string was sent"
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
