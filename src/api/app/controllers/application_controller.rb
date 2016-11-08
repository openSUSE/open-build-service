# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require_dependency 'opensuse/permission'
require_dependency 'opensuse/backend'
require_dependency 'opensuse/validator'
require_dependency 'api_exception'

class ApplicationController < ActionController::Base
  include Pundit
  protect_from_forgery

  include ForbidsAnonymousUsers

  class NoDataEntered < APIException
    setup 403
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
  before_action :require_login

  # contains current authentification method, one of (:proxy, :basic)
  attr_accessor :auth_method

  def pundit_user
    if User.current.is_nobody?
      return nil
    else
      return User.current
    end
  end

  # Method for mapping actions in a controller to (XML) schemas based on request
  # method (GET, PUT, POST, etc.). Example:
  #
  # class UserController < ActionController::Base
  #   # Validation on request data is performed based on the request type and the
  #   # provided schema name. Validation for a GET request only checks the XML response,
  #   # whereas a POST request may want to check the (user-supplied) request as well as the
  #   # own response to the request.
  #
  #   validate_action :index => {:method => :get, :response => :users}
  #   validate_action :edit =>  {:method => :put, :request => :user, :response => :status}
  #
  #   def index
  #     # return all users ...
  #   end
  #
  #   def edit
  #     if @request.put?
  #       # request data has already been validated here
  #     end
  #   end
  # end
  def self.validate_action(opt)
    opt.each do |action, action_opt|
      Suse::Validator.add_schema_mapping(controller_path, action, action_opt)
    end
  end

  protected

  def load_nobody
    @http_user = User.find_nobody!
    User.current = @http_user
    @user_permissions = Suse::Permission.new( User.current )
  end

  def require_admin
    logger.debug "Checking for  Admin role for user #{@http_user.login}"
    unless @http_user.is_admin?
      logger.debug "not granted!"
      render_error(status: 403, errorcode: "put_request_no_permission", message: "Requires admin privileges") && (return false)
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

  def extract_proxy_user
    @auth_method = :proxy
    proxy_user = request.env['HTTP_X_USERNAME']
    if proxy_user
      logger.info "iChain user extracted from header: #{proxy_user}"
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
        # Generate and store a fake pw in the OBS DB that no-one knows
        # FIXME: we should allow NULL passwords in DB, but that needs user management cleanup
        chars = ["A".."Z", "a".."z", "0".."9"].collect { |r| r.to_a }.join
        fakepw = (1..24).collect { chars[rand(chars.size)] }.pack("a"*24)
        @http_user = User.new(
            login: proxy_user,
            state: User.default_user_state,
            password: fakepw)
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

    if authorization && authorization[0] == "Basic"
      # logger.debug( "AUTH2: #{authorization}" )
      @login, @passwd = Base64.decode64(authorization[1]).split(':', 2)[0..1]

      # set password to the empty string in case no password is transmitted in the auth string
      @passwd ||= ""
    else
      logger.debug "no authentication string was sent"
    end
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

  def require_login
    # we allow anonymous user only for rare special operations (if configured) but we require
    # a valid account for all other operations.
    # For this rare special operations we simply skip the require login before filter!
    # At the moment these operations are the /public, /trigger and /about controller actions.
    be_not_nobody!
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
      logger.debug "USER found: #{@http_user.login}"
      @user_permissions = Suse::Permission.new(@http_user)
      return true
    end

    raise InactiveUserError.new "User is registered but not in confirmed state. Your account is a registered account, " +
                                "but it is in a not active state."
  end

  def require_valid_project_name
    required_parameters :project
    valid_project_name!(params[:project])
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

  def volley_backend_path(path)
    logger.debug "[backend] VOLLEY: #{path}"
    Suse::Backend.start_test_backend
    backend_http = Net::HTTP.new(CONFIG['source_host'], CONFIG['source_port'])
    backend_http.read_timeout = 1000

    # we have to be careful with object life cycle. the actual data is
    # deleted once the tempfile is garbage collected, but isn't kept alive
    # as the send_file function only references the path to it. So we keep it
    # for ourselves. And once the controller is garbage collected, it should
    # be fine to unlink the data
    @volleyfile = Tempfile.new 'volley', encoding: 'ascii-8bit'
    opts = { url_based_filename: true }

    backend_http.request_get(path) do |res|
      opts[:status] = res.code
      opts[:type] = res['Content-Type']
      res.read_body do |segment|
        @volleyfile.write(segment)
      end
    end
    opts[:length] = @volleyfile.length
    opts[:disposition] = 'inline' if %w(text/plain text/xml).include?(opts[:type])
    # streaming makes it very hard for test cases to verify output
    opts[:stream] = false if Rails.env.test?
    send_file(@volleyfile.path, opts)
    # close the file so it's not staying in the file system
    @volleyfile.close
  end

  def download_request
    file = Tempfile.new 'volley', encoding: 'ascii-8bit'
    b = request.body
    buffer = String.new
    file.write(buffer) while b.read(40960, buffer)
    file.close
    file.open
    file
  end

  def get_request_path
    path = request.path_info
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
      volley_backend_path(path) unless forward_from_backend(path)
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
    send_data( text, type: response.fetch( "content-type" ),
      disposition: "inline" )
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

  rescue_from ActiveXML::ParseError do
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
    render plain: text, status: http_status
  end

  rescue_from Project::WritePermissionError do |exception|
    render_error status: 403, errorcode: "modify_project_no_permission", message: exception.message
  end

  rescue_from Package::WritePermissionError do |exception|
    render_error status: 403, errorcode: "modify_package_no_permission", message: exception.message
  end

  rescue_from ActiveXML::Transport::NotFoundError, ActiveRecord::RecordNotFound do |exception|
    render_error message: exception.message, status: 404, errorcode: 'not_found'
  end

  rescue_from ActionController::RoutingError do |exception|
    render_error message: exception.message, status: 404, errorcode: 'not_route'
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

  def gather_exception_defaults(opt)
    if opt[:message]
      @summary = opt[:message]
    elsif @exception
      @summary = @exception.message
    end

    @exception = opt[:exception]
    @errorcode = opt[:errorcode]

    if opt[:status]
      @status = opt[:status].to_i
    else
      @status = 400
    end

    if @status == 401
      response.headers["WWW-Authenticate"] = 'basic realm="API login"'
    end
    if @status == 404
      @summary ||= "Not found"
      @errorcode ||= "not_found"
    end

    @summary ||= "Internal Server Error"

    if @exception
      @errorcode ||= 'uncaught_exception'
    else
      @errorcode ||= 'unknown'
    end
  end

  def render_error( opt = {} )
    # avoid double render error
    self.response_body = nil
    gather_exception_defaults(opt)

    response.headers['X-Opensuse-Errorcode'] = @errorcode
    respond_to do |format|
      format.xml { render template: 'status', status: @status }
      format.json { render json: { errorcode: @errorcode, summary: @summary }, status: @status }
      format.html do
        unless request.env['HTTP_REFERER']
          flash[:error] = "#{@errorcode}(#{@summary}): #{@message}"
        end
        redirect_back(fallback_location: root_path)
      end
    end
  end

  def render_ok(opt = {})
    # keep compatible to old call style
    @errorcode = "ok"
    @summary = "Ok"
    @data = opt[:data] if opt[:data]
    render template: 'status', status: 200
  end

  def render_invoked(opt = {})
    @errorcode = "invoked"
    @summary = "Job invoked"
    @data = opt[:data] if opt[:data]
    render template: 'status', status: 200
  end

  def backend
    Suse::Backend.start_test_backend if Rails.env.test?
    @backend ||= ActiveXML.backend
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
  def dispatch_command(action, cmd)
    cmd_handler = "#{action}_#{cmd}"
    logger.debug "dispatch_command: trying to call method '#{cmd_handler}'"
    __send__ cmd_handler
  end

  def build_query_from_hash(hash, key_list = nil)
    Suse::Backend.build_query_from_hash(hash, key_list)
  end

  class LazyRequestReader
    def initialize(req)
      @req = req
    end

    def to_s
      @req.raw_post
    end
  end

  def validate_xml_request(method = nil)
    opt = params
    opt[:method] = method || request.method.to_s
    opt[:type] = 'request'
    logger.debug "Validate XML request: #{request}"
    Suse::Validator.validate(opt, LazyRequestReader.new(request))
  end

  def validate_xml_response
    return if @skip_validation
    # rubocop:disable Metrics/LineLength
    if request.format != 'json' && response.status.to_s[0..2] == '200' && response.headers['Content-Type'] !~ /.*\/json/i && response.headers['Content-Disposition'] != 'attachment'
      opt = params()
      opt[:method] = request.method.to_s
      opt[:type] = 'response'
      ms = Benchmark.ms do
        if response.body.respond_to? :call
          sio = StringIO.new()
          response.body.call(nil, sio) # send_file can return a block that takes |response, output|
          str = sio.string
        else
          str = response.body
        end
        Suse::Validator.validate(opt, str)
      end
      logger.debug "Validate XML response: #{response} took #{Integer(ms + 0.5)}ms"
    end
    # rubocop:enable Metrics/LineLength
  end

  def set_response_format_to_xml
    request.format = :xml if request.format == :html
  end

  private

  def forward_from_backend(path)
    # apache & mod_xforward case
    if CONFIG['use_xforward'] && CONFIG['use_xforward'] != "false"
      logger.debug "[backend] VOLLEY(mod_xforward): #{path}"
      headers['X-Forward'] = "http://#{CONFIG['source_host']}:#{CONFIG['source_port']}#{path}"
      headers['Cache-Control'] = 'no-transform' # avoid compression
      head(200)
      @skip_validation = true
      return true
    end

    # lighttpd 1.5 case
    if CONFIG['x_rewrite_host']
      logger.debug "[backend] VOLLEY(lighttpd): #{path}"
      headers['X-Rewrite-URI'] = path
      headers['X-Rewrite-Host'] = CONFIG['x_rewrite_host']
      headers['Cache-Control'] = 'no-transform' # avoid compression
      head(200)
      @skip_validation = true
      return true
    end

    # nginx case
    if CONFIG['use_nginx_redirect']
      logger.debug "[backend] VOLLEY(nginx): #{path}"
      headers['X-Accel-Redirect'] = "#{CONFIG['use_nginx_redirect']}/http/#{CONFIG['source_host']}:#{CONFIG['source_port']}#{path}"
      headers['Cache-Control'] = 'no-transform' # avoid compression
      head(200)
      @skip_validation = true
      return true
    end

    false
  end

  def shutup_rails
    Rails.cache.silence! unless Rails.env.development?
  end
end
