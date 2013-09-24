# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require_dependency 'opensuse/permission'
require_dependency 'opensuse/backend'
require_dependency 'opensuse/validator'
require_dependency 'api_exception'

class ApplicationController < ActionController::Base

  class InvalidHttpMethodError < APIException
    setup 'invalid_http_method'
  end
  class MissingParameterError < APIException
    setup 'missing_parameter'
  end
  class InvalidParameterError < APIException
    setup "invalid_parameter"
  end

  class InvalidProjectName < APIException
    setup 400
  end

  class NoDataEntered < APIException
    setup 403
  end

  class UnknownCommandError < APIException
  end
  class AuthenticationRequiredError < APIException
    setup 401, "Authentication required"
  end

  include ActionController::ImplicitRender
  include ActionController::MimeResponds

  # session :disabled => true

  @user_permissions = nil
  @http_user = nil
  @skip_validation = false

  before_action :validate_xml_request, :add_api_version
  if CONFIG['response_schema_validation'] == true
    after_action :validate_xml_response
  end

  # skip the filter for the user stuff
  before_action :extract_user
  before_action :setup_backend
  before_action :shutup_rails
  before_action :validate_params

  #contains current authentification method, one of (:proxy, :basic)
  attr_accessor :auth_method
  
  protected

  def load_nobody
    @http_user = User.find_by_login( "_nobody_" )
    User.current = @http_user
    User.current.is_admin = false
    @user_permissions = Suse::Permission.new( User.current )
  end

  def require_admin
    logger.debug "Checking for  Admin role for user #{@http_user.login}"
    unless @http_user.is_admin?
      logger.debug "not granted!"
      render_error :status => 403, :errorcode => "put_request_no_permission", :message => "Requires admin privileges" and return false
    end
    return true
  end

  def validate_params
    params.each do |key, value|
      next if value.nil?
      next if key == 'xmlhash' # perfectly fine
      if !value.kind_of? String
        raise InvalidParameterError, "Parameter #{key} has non String class #{value.class}"
      end
    end
    return true
  end

  class InactiveUserError < APIException
    setup 403
  end

  class UnconfirmedUserError < APIException
    setup 403
  end

  class UnregisteredUserError < APIException
    setup 403
  end

  def extract_ldap_user
    begin
      require 'ldap'
      logger.debug( "Using LDAP to find #{@login}" )
      ldap_info = User.find_with_ldap( @login, @passwd )
    rescue LoadError
      logger.warn "ldap_mode selected but 'ruby-ldap' module not installed."
      ldap_info = nil # now fall through as if we'd not found a user
    rescue Exception
      logger.debug "#{login} not found in LDAP."
      ldap_info = nil # now fall through as if we'd not found a user
    end

    if ldap_info
      # We've found an ldap authenticated user - find or create an OBS userDB entry.
      @http_user = User.find_by_login( login )
      if @http_user
        # Check for ldap updates
        if @http_user.email != ldap_info[0]
          @http_user.email = ldap_info[0]
          @http_user.save
        end
      else
        if ::Configuration.registration == "deny"
          logger.debug( "No user found in database, creation disabled" )
          @http_user=nil
          raise AuthenticationRequiredError.new "User '#{login}' does not exist<br>#{errstr}"
        end
        logger.debug( "No user found in database, creating" )
        logger.debug( "Email: #{ldap_info[0]}" )
        logger.debug( "Name : #{ldap_info[1]}" )
        # Generate and store a fake pw in the OBS DB that no-one knows
        chars = ["A".."Z","a".."z","0".."9"].collect { |r| r.to_a }.join
        fakepw = (1..24).collect { chars[rand(chars.size)] }.pack('a'*24)
        newuser = User.create(
            :login => login,
            :password => fakepw,
            :password_confirmation => fakepw,
            :email => ldap_info[0] )
        unless newuser.errors.empty?
          errstr = String.new
          logger.debug("Creating User failed with: ")
          newuser.errors.each_full do |msg|
            errstr = errstr+msg
            logger.debug(msg)
          end
          @http_user=nil
          raise AuthenticationRequiredError.new "Cannot create ldap userid: '#{login}' on OBS<br>#{errstr}"
        end
        newuser.realname = ldap_info[1]
        newuser.state = User.states['confirmed']
        newuser.state = User.states['unconfirmed'] if ::Configuration.registration == "confirmation"
        newuser.adminnote = "User created via LDAP"
        user_role = Role.find_by_title("User")
        newuser.roles << user_role

        logger.debug( "saving new user..." )
        newuser.save

        @http_user = newuser
      end
    else
      logger.debug( "User not found with LDAP, falling back to database" )
    end

  end

  def extract_proxy_user(mode)
    @auth_method = :proxy
    proxy_user = request.env['HTTP_X_USERNAME']
    if proxy_user
      logger.info "iChain user extracted from header: #{proxy_user}"
    elsif mode == :simulate
      proxy_user = CONFIG['proxy_auth_test_user']
      logger.debug "iChain user extracted from config: #{proxy_user}"
    end

    # we're using a login proxy, there is no need to authenticate the user from the credentials
    # However we have to care for the status of the user that must not be unconfirmed or proxy requested
    if proxy_user
      @http_user = User.find_by_login proxy_user

      # If we do not find a User here, we need to create a user and wait for
      # the confirmation by the user and the BS Admin Team.
      unless @http_user
        if ::Configuration.registration == "deny"
          logger.debug("No user found in database, creation disabled")
          raise AuthenticationRequiredError.new "User '#{login}' does not exist<br>#{errstr}"
        end
        state = User.states['confirmed']
        state = User.states['unconfirmed'] if ::Configuration.registration == "confirmation"
        # Generate and store a fake pw in the OBS DB that no-one knows
        # FIXME: we should allow NULL passwords in DB, but that needs user management cleanup
        chars = ["A".."Z", "a".."z", "0".."9"].collect { |r| r.to_a }.join
        fakepw = (1..24).collect { chars[rand(chars.size)] }.pack("a"*24)
        @http_user = User.create(
            :login => proxy_user,
            :password => fakepw,
            :password_confirmation => fakepw,
            :state => state)
      end

      # update user data from login proxy headers
      @http_user.update_user_info_from_proxy_env(request.env) if @http_user
    else
      logger.error "No X-username header from login proxy! Are we really using an authentification proxy?"
    end

  end

  def authorization_infos
    # 1. try to get it where mod_rewrite might have put it
    # 2. for Apace/mod_fastcgi with -pass-header Authorization
    # 3. regular location
    %w{X-HTTP_AUTHORIZATION Authorization HTTP_AUTHORIZATION}.each do |header|
      if request.env.has_key? header
        return request.env[header].to_s.split
      end
    end
    return nil
  end

  def extract_basic_auth_user
    authorization = authorization_infos

    # privacy! logger.debug( "AUTH: #{authorization.inspect}" )

    if authorization and authorization[0] == "Basic"
      # logger.debug( "AUTH2: #{authorization}" )
      @login, @passwd = Base64.decode64(authorization[1]).split(':', 2)[0..1]

      #set password to the empty string in case no password is transmitted in the auth string
      @passwd ||= ""
    else
      logger.debug "no authentication string was sent"
    end
  end

  def extract_user
    mode = CONFIG['proxy_auth_mode'] || CONFIG['ichain_mode'] || :basic
    if mode == :on || mode == :simulate # configured in the the environment file
      extract_proxy_user mode
    else
      @auth_method = :basic

      extract_basic_auth_user

      if CONFIG['ldap_mode'] == :on
        # disallow empty passwords to prevent LDAP lockouts
        if @passwd.blank?
          raise AuthenticationRequiredError.new "User '#{@login}' did not provide a password"
        end

        extract_ldap_user
      end

      if @login && !@http_user
        @http_user = User.find_with_credentials @login, @passwd
      end
    end

    check_extracted_user
  end

  def check_for_anonymous_user
    if ::Configuration.anonymous?
      read_only_hosts = []
      read_only_hosts = CONFIG['read_only_hosts'] if CONFIG['read_only_hosts']
      read_only_hosts << CONFIG['webui_host'] if CONFIG['webui_host'] # this was used in config files until OBS 2.1
      if read_only_hosts.include?(request.env['REMOTE_HOST']) or read_only_hosts.include?(request.env['REMOTE_ADDR'])
        # Fixed list of clients which do support the read only mode
        hua = request.env['HTTP_USER_AGENT']
        if hua && (hua.match(/^obs-webui/) || hua.match(/^obs-software/))
          load_nobody
          return true
        end
      else
        logger.info "anononymous configured, but #{read_only_hosts.inspect} does not include '#{request.env['REMOTE_HOST']}' '#{request.env['REMOTE_ADDR']}'"
      end
    end
    return false
  end

  def check_extracted_user
    unless @http_user
      if @login.blank?
        return true if check_for_anonymous_user
        raise AuthenticationRequiredError.new
      end
      raise AuthenticationRequiredError.new "Unknown user '#{@login}' or invalid password"
    end

    if @http_user.state == User.states['ichainrequest'] or @http_user.state == User.states['unconfirmed']
      raise UnconfirmedUserError.new "User is registered but not yet approved. " +
                                         "Your account is a registered account, but it is not yet approved for the OBS by admin."
    end

    User.current = @http_user

    if @http_user.state == User.states['confirmed']
      logger.debug "USER found: #{@http_user.login}"
      @user_permissions = Suse::Permission.new(@http_user)
      return true
    end

    raise InactiveUserError.new "User is registered but not in confirmed state. Your account is a registered account, but it is in a not active state."
  end

  def require_valid_project_name
    required_parameters :project
    raise InvalidProjectName.new("invalid project name '#{params[:project]}'") unless valid_project_name?(params[:project])
    # important because otherwise the filter chain is stopped
    return true
  end

  def setup_backend
    # initialize backend on every request
    Suse::Backend.source_host = CONFIG['source_host']
    Suse::Backend.source_port = CONFIG['source_port']
  end

  def add_api_version
    response.headers["X-Opensuse-APIVersion"] = "#{CONFIG['version']}"
  end

  hide_action :forward_from_backend
  def forward_from_backend(path)

    # apache & mod_xforward case
    if CONFIG['use_xforward'] and CONFIG['use_xforward'] != "false"
      logger.debug "[backend] VOLLEY(mod_xforward): #{path}"
      headers['X-Forward'] = "http://#{CONFIG['source_host']}:#{CONFIG['source_port']}#{path}"
      head(200)
      @skip_validation = true
      return
    end

    # lighttpd 1.5 case
    if CONFIG['x_rewrite_host']
      logger.debug "[backend] VOLLEY(lighttpd): #{path}"
      headers['X-Rewrite-URI'] = path
      headers['X-Rewrite-Host'] = CONFIG['x_rewrite_host']
      head(200)
      @skip_validation = true
      return
    end

    # nginx case
    if CONFIG['use_nginx_redirect']
      logger.debug "[backend] VOLLEY(nginx): #{path}"
      headers['X-Accel-Redirect'] = "#{CONFIG['use_nginx_redirect']}/http/#{CONFIG['source_host']}:#{CONFIG['source_port']}#{path}"
      head(200)
      @skip_validation = true
      return
    end

    logger.debug "[backend] VOLLEY: #{path}"
    Suse::Backend.start_test_backend 
    backend_http = Net::HTTP.new(CONFIG['source_host'], CONFIG['source_port'])
    backend_http.read_timeout = 1000

    # we have to be careful with object life cycle. the actual data is
    # deleted once the tempfile is garbage collected, but isn't kept alive 
    # as the send_file function only references the path to it. So we keep it
    # for ourselves. And once the controller is garbage collected, it should
    # be fine to unlink the data
    @volleyfile = Tempfile.new 'volley', :encoding => 'ascii-8bit'
    opts = { :url_based_filename => true }
    
    backend_http.request_get(path) do |res|
      opts[:status] = res.code
      opts[:type] = res['Content-Type']
      res.read_body do |segment|
        @volleyfile.write(segment)
      end
    end
    opts[:length] = @volleyfile.length
    # streaming makes it very hard for test cases to verify output
    opts[:stream] = false if Rails.env.test?
    send_file(@volleyfile.path, opts)
    # close the file so it's not staying in the file system
    @volleyfile.close
  end

  def download_request
    file = Tempfile.new 'volley', :encoding => 'ascii-8bit'
    b = request.body
    buffer = String.new
    while b.read(40960, buffer)
      file.write(buffer)
    end
    file.close
    file.open
    file
  end

  def get_request_path
    path = request.path
    query_string = request.query_string
    if request.form_data?
      # it's uncommon, but possible that we have both
      query_string += "&" unless query_string.blank?
      query_string += request.raw_post
    end
    query_string = "?" + query_string unless query_string.blank?
    path + query_string 
  end

  def pass_to_backend( path = nil )

    path ||= get_request_path

    if request.get? || request.head?
      forward_from_backend( path )
      return
    end
    case request.method_symbol
    when :post
      # for form data we don't need to download anything
      if request.form_data?
        response = Suse::Backend.post( path, '', { 'Content-Type' => 'application/x-www-form-urlencoded' } )
      else
        file = download_request
        response = Suse::Backend.post( path, file )
        file.close!
      end
    when :put
      file = download_request
      response = Suse::Backend.put( path, file )
      file.close!
    when :delete
      response = Suse::Backend.delete( path )
    end

    text = response.body
    send_data( text, :type => response.fetch( "content-type" ),
      :disposition => "inline" )
    return text
  end
  public :pass_to_backend

  rescue_from ActiveRecord::RecordInvalid do |exception|
    render_error status: 400, errorcode: "invalid_record", message: exception.record.errors.full_messages.join('\n')
  end

  rescue_from ActiveXML::Transport::Error do |exception|
    render_error status: exception.code, errorcode: "uncaught_exception", message: exception.summary
  end

  rescue_from Timeout::Error do |exception|
    render_error status: 408, errorcode: "timeout_error", message: exception.message
  end

  rescue_from ActiveXML::ParseError do |exception|
    render_error status: 400, errorcode: 'invalid_xml', message: "Invalid XML"
  end

  rescue_from APIException do |exception|
    bt = exception.backtrace.join("\n")
    logger.debug "#{exception.class.name} #{exception.message} #{bt}"
    message = exception.message
    if message.blank? || message == exception.class.name
      message = exception.default_message
    end
    render_error message: message, status: exception.status, errorcode: exception.errorcode
  end

  rescue_from ActiveXML::Transport::Error do |exception|
    text = exception.message
    http_status = 500
    begin
      xml = ActiveXML::Node.new( text )
      http_status = xml.value('code')
      unless xml.has_attribute? 'origin'
        xml.set_attribute "origin", "backend"
      end
      text = xml.dump_xml
    rescue ActiveXML::ParseError
    end
    render text: text, status: http_status
  end

  rescue_from Project::WritePermissionError do |exception|
    render_error :status => 403, :errorcode => "modify_project_no_permission", :message => exception.message
  end

  rescue_from Package::WritePermissionError do |exception|
    render_error :status => 403, :errorcode => "modify_package_no_permission", :message => exception.message
  end

  rescue_from ActiveXML::Transport::NotFoundError, ActiveRecord::RecordNotFound do |exception|
    render_error message: exception.message, status: 404, errorcode: 'not_found'
  end

  def permissions
    return @user_permissions
  end

  def user
    return @http_user
  end

  def require_parameter!(parameter)
    unless params.include? parameter.to_s
      raise MissingParameterError, "Required Parameter #{parameter} missing"
    end
  end

  def required_parameters(*parameters)
    parameters.each { |parameter| require_parameter!(parameter) }
  end

  def required_fields(*parameters)
    parameters.each do |parameter|
      require_parameter!(parameter)
      if params[parameter].blank?
        raise NoDataEntered.new "Required Parameter #{parameter} is empty"
      end
    end
  end

  def render_error( opt = {} )
    # workaround an exception in mod_rails, it dies when an answer is send without
    # reading the body. We trigger passenger to read the entire body via requesting the size
    if request.put? or request.post?
      request.body.size if request.body.respond_to? 'size'
    end

    if opt[:message]
      @summary = opt[:message]
    elsif @exception
      @summary = @exception.message
    end

    @exception = opt[:exception]
    @errorcode = opt[:errorcode]
    
    opt[:status] ||= 400

    if opt[:status].to_i == 401
      response.headers["WWW-Authenticate"] = 'basic realm="API login"'
    end
    if opt[:status].to_i == 404
      @summary ||= "Not found"
      @errorcode ||= "not_found"
    end
    
    @summary ||= "Internal Server Error"

    if @exception
      @errorcode ||= 'uncaught_exception'
    end

    @errorcode ||= 'unknown'

    response.headers['X-Opensuse-Errorcode'] = @errorcode
    respond_to do |format|
      format.xml { render template: 'status', status: opt[:status] }
      format.json { render json: { errorcode: @errorcode, summary: @summary }, status: opt[:status] }
    end
  end

  class AnonymousUser < APIException
   setup 401
  end

  def be_not_nobody!
    if !User.current || User.current.is_nobody?
      raise AnonymousUser.new  "Anonymous user is not allowed here - please login"
    end 
  end

  def render_ok(opt={})
    # keep compatible to old call style
    @errorcode = "ok"
    @summary = "Ok"
    @data = opt[:data] if opt[:data]
    render :template => 'status', :status => 200
  end

  def render_invoked(opt={})
    @errorcode = "invoked"
    @summary = "Job invoked"
    @data = opt[:data] if opt[:data]
    render :template => 'status', :status => 200
  end

  def backend
    Suse::Backend.start_test_backend if Rails.env.test?
    @backend ||= ActiveXML.transport
  end

  def backend_get( path )
    # TODO: check why not using SUSE:Backend::get
    backend.direct_http( URI(path) )
  end

  # Passes control to subroutines determined by action and a request parameter. By
  # default the parameter assumed to contain the command is ':cmd'. Looks for a method
  # named <action>_<command>
  #
  # Example:
  #
  # If you call dispatch_command from an action 'index' with the query parameter cmd
  # having the value 'show', it will call the method 'index_show'
  #
  def dispatch_command(opt={})
    defaults = {
      :cmd_param => :cmd
    }
    opt = defaults.merge opt
    require_parameter! opt[:cmd_param]

    cmd_handler = "#{params[:action]}_#{params[opt[:cmd_param]]}"
    logger.debug "dispatch_command: trying to call method '#{cmd_handler}'"

    if not self.respond_to? cmd_handler, true
      raise UnknownCommandError.new "Unknown command '#{params[opt[:cmd_param]]}' for path #{request.path}"
    end

    __send__ cmd_handler
  end
  public :dispatch_command
  hide_action :dispatch_command


  def build_query_from_hash(hash, key_list=nil)
    Suse::Backend.build_query_from_hash(hash, key_list)
  end

  private
  def shutup_rails
    Rails.cache.silence! unless Rails.env.development?
  end

end
