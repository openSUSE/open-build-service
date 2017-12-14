# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require_dependency 'opensuse/validator'
require_dependency 'api_exception'
require_dependency 'authenticator'

class ApplicationController < ActionController::Base
  include Pundit
  protect_from_forgery

  include ActionController::ImplicitRender
  include ActionController::MimeResponds

  # session :disabled => true

  @skip_validation = false

  before_action :validate_xml_request, :add_api_version
  if CONFIG['response_schema_validation'] == true
    after_action :validate_xml_response
  end

  # skip the filter for the user stuff
  before_action :extract_user
  before_action :shutup_rails
  before_action :validate_params
  before_action :require_login

  delegate :extract_user,
           :extract_user_public,
           :require_login,
           :require_admin,
           to: :authenticator

  def authenticator
    @authenticator ||= Authenticator.new(request, session, response)
  end

  def pundit_user
    return User.current unless User.current.is_nobody?
  end

  def peek_enabled?
    User.current && (User.current.is_admin? || User.current.is_staff?)
  end

  def permissions
    authenticator.user_permissions
  end

  # TODO: There are currently two ways of accessing the logged in user: User.curent and user
  #       We should pick only one of them to use.
  def user
    authenticator.http_user
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

  def validate_params
    params.each do |key, value|
      next if value.nil?
      next if key == 'xmlhash' # perfectly fine
      unless value.kind_of? String
        raise InvalidParameterError, "Parameter #{key} has non String class #{value.class}"
      end
    end
    true
  end

  def require_valid_project_name
    required_parameters :project
    valid_project_name!(params[:project])
    # important because otherwise the filter chain is stopped
    true
  end

  def add_api_version
    response.headers['X-Opensuse-APIVersion'] = (CONFIG['version']).to_s
  end

  def volley_backend_path(path)
    logger.debug "[backend] VOLLEY: #{path}"
    Backend::Test.start
    backend_http = Net::HTTP.new(CONFIG['source_host'], CONFIG['source_port'])
    backend_http.read_timeout = 1000

    # we have to be careful with object life cycle. the actual data is
    # deleted once the tempfile is garbage collected, but isn't kept alive
    # as the send_file function only references the path to it. So we keep it
    # for ourselves. And once the controller is garbage collected, it should
    # be fine to unlink the data
    @volleyfile = Tempfile.new('volley', "#{Rails.root}/tmp", encoding: 'ascii-8bit')
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
    file = Tempfile.new('volley', "#{Rails.root}/tmp", encoding: 'ascii-8bit')
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
      query_string += '&' if query_string.present?
      query_string += request.raw_post
    end
    query_string = '?' + query_string if query_string.present?
    path + query_string
  end

  def pass_to_backend(path = nil)
    path ||= get_request_path

    if request.get? || request.head?
      volley_backend_path(path) unless forward_from_backend(path)
      return
    end
    case request.method_symbol
    when :post
      # for form data we don't need to download anything
      if request.form_data?
        response = Backend::Connection.post(path, '', 'Content-Type' => 'application/x-www-form-urlencoded')
      else
        file = download_request
        response = Backend::Connection.post(path, file)
        file.close!
      end
    when :put
      file = download_request
      response = Backend::Connection.put(path, file)
      file.close!
    when :delete
      response = Backend::Connection.delete(path)
    end

    text = response.body
    send_data(text, type: response.fetch('content-type'),
      disposition: 'inline')
    text
  end
  public :pass_to_backend

  rescue_from ActiveRecord::RecordInvalid do |exception|
    render_error status: 400, errorcode: 'invalid_record', message: exception.record.errors.full_messages.join('\n')
  end

  rescue_from ActiveXML::Transport::Error do |exception|
    render_error status: exception.code, errorcode: 'uncaught_exception', message: exception.summary
  end

  rescue_from Timeout::Error do |exception|
    render_error status: 408, errorcode: 'timeout_error', message: exception.message
  end

  rescue_from ActiveXML::ParseError do
    render_error status: 400, errorcode: 'invalid_xml', message: 'Invalid XML'
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
      xml = ActiveXML::Node.new(text)
      http_status = xml.value('code')
      unless xml.has_attribute? 'origin'
        xml.set_attribute 'origin', 'backend'
      end
      text = xml.dump_xml
    rescue ActiveXML::ParseError
    end
    render plain: text, status: http_status
  end

  rescue_from Project::WritePermissionError do |exception|
    render_error status: 403, errorcode: 'modify_project_no_permission', message: exception.message
  end

  rescue_from Package::WritePermissionError do |exception|
    render_error status: 403, errorcode: 'modify_package_no_permission', message: exception.message
  end

  rescue_from ActiveXML::Transport::NotFoundError, ActiveRecord::RecordNotFound do |exception|
    render_error message: exception.message, status: 404, errorcode: 'not_found'
  end

  rescue_from ActionController::RoutingError do |exception|
    render_error message: exception.message, status: 404, errorcode: 'not_route'
  end

  rescue_from Pundit::NotAuthorizedError do |exception|
    message = 'You are not authorized to perform this action.'

    pundit_action =
      case exception.try(:query).to_s
      when 'index?' then 'list'
      when 'show?' then 'view'
      when 'create?' then 'create'
      when 'new?' then 'create'
      when 'update?' then 'update'
      when 'edit?' then 'edit'
      when 'destroy?' then 'delete'
      when 'branch?' then 'branch'
      else exception.try(:query)
      end

    if pundit_action && exception.record
      message = "You are not authorized to #{pundit_action} this #{ActiveSupport::Inflector.underscore(exception.record.class.to_s).humanize}."
    end

    render_error status: 403,
                 errorcode: "#{pundit_action}_#{ActiveSupport::Inflector.underscore(exception.record.class.to_s)}_not_authorized",
                 message: message
  end

  def require_parameter!(parameter)
    raise MissingParameterError, "Required Parameter #{parameter} missing" unless params.include? parameter.to_s
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
      unless response.headers['WWW-Authenticate']
        if CONFIG['kerberos_mode']
          response.headers['WWW-Authenticate'] = 'Negotiate'
        else
          response.headers['WWW-Authenticate'] = 'basic realm="API login"'
        end
      end
    end
    if @status == 404
      @summary ||= 'Not found'
      @errorcode ||= 'not_found'
    end

    @summary ||= 'Internal Server Error'

    if @exception
      @errorcode ||= 'uncaught_exception'
    else
      @errorcode ||= 'unknown'
    end
  end

  def render_error(opt = {})
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
    @errorcode = 'ok'
    @summary = 'Ok'
    @data = opt[:data] if opt[:data]
    render template: 'status', status: 200
  end

  def render_invoked(opt = {})
    @errorcode = 'invoked'
    @summary = 'Job invoked'
    @data = opt[:data] if opt[:data]
    render template: 'status', status: 200
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
    Backend::Connection.build_query_from_hash(hash, key_list)
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

    request_format = request.format != 'json'
    response_status = response.status.to_s[0..2] == '200'
    response_headers = response.headers['Content-Type'] !~ /.*\/json/i && response.headers['Content-Disposition'] != 'attachment'

    return unless request_format && response_status && response_headers

    opt = params
    opt[:method] = request.method.to_s
    opt[:type] = 'response'
    ms = Benchmark.ms do
      if response.body.respond_to? :call
        sio = StringIO.new
        response.body.call(nil, sio) # send_file can return a block that takes |response, output|
        str = sio.string
      else
        str = response.body
      end
      Suse::Validator.validate(opt, str)
    end
    logger.debug "Validate XML response: #{response} took #{Integer(ms + 0.5)}ms"
  end

  def set_response_format_to_xml
    request.format = :xml if request.format == :html
  end

  private

  def forward_from_backend(path)
    # apache & mod_xforward case
    if CONFIG['use_xforward'] && CONFIG['use_xforward'] != 'false'
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
