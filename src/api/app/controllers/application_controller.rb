# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'api_error'

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  protect_from_forgery

  include ActionController::ImplicitRender
  include ActionController::MimeResponds
  include FlipperFeature

  include RescueHandler
  include RescueAuthorizationHandler
  include SetCurrentRequestDetails
  include BackendProxy

  # session :disabled => true

  @skip_validation = false

  # Each request starts out with the nobody user set.
  before_action :set_nobody

  before_action :add_api_version

  # skip the filter for the user stuff
  before_action :extract_user
  before_action :set_influxdb_data
  before_action :shutup_rails
  before_action :validate_params
  before_action :require_login

  before_action :validate_xml_request
  after_action :validate_xml_response if CONFIG['response_schema_validation'] == true

  delegate :extract_user,
           :extract_user_public,
           :require_login,
           :require_admin,
           to: :authenticator

  def authenticator
    @authenticator ||= Authenticator.new(request, session, response)
  end

  def pundit_user
    User.session
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
      raise InvalidParameterError, "Parameter #{key} has non String class #{value.class}" unless value.is_a?(String)
    end
  end

  def require_scmsync_host_check
    scm_cookie = request.env['HTTP_X_SCM_BRIDGE_COOKIE']
    raise MissingParameterError, 'X-SCM_BRIDGE_COOKIE is not set' if scm_cookie.blank?
    raise MissingParameterError, 'Incorrect scm bridge cookie' if scm_cookie != CONFIG['scm_bridge_cookie'].to_s
  end

  def add_api_version
    response.headers['X-Opensuse-APIVersion'] = CONFIG['version'].to_s
  end

  def require_parameter!(parameter)
    raise MissingParameterError, "Required Parameter #{parameter} missing" unless params.include?(parameter.to_s)
  end

  def required_parameters(*parameters)
    parameters.each { |parameter| require_parameter!(parameter) }
  end

  def gather_exception_defaults(opt)
    if opt[:message]
      @summary = opt[:message].to_s
    elsif @exception
      @summary = @exception.message
    end

    @exception = opt[:exception]
    @errorcode = opt[:errorcode]

    @status = if opt[:status]
                opt[:status].to_i
              else
                400
              end

    if @status == 401 && !response.headers['WWW-Authenticate']
      response.headers['WWW-Authenticate'] = if CONFIG['kerberos_mode']
                                               'Negotiate'
                                             else
                                               'basic realm="API login"'
                                             end
    end
    if @status == 404
      @summary ||= 'Not found'
      @errorcode ||= 'not_found'
    end

    @summary ||= 'Internal Server Error'

    @errorcode ||= if @exception
                     'uncaught_exception'
                   else
                     'unknown'
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
        flash[:error] = "#{@summary} (#{@errorcode})" unless request.env['HTTP_REFERER']
        redirect_back_or_to root_path
      end
    end
  end

  def render_ok(opt = {})
    # keep compatible to old call style
    @errorcode = 'ok'
    @summary = 'Ok'
    @data = opt[:data] if opt[:data]
    render template: 'status', status: :ok
  end

  def render_invoked(opt = {})
    @errorcode = 'invoked'
    @summary = 'Job invoked'
    @data = opt[:data] if opt[:data]
    render template: 'status', status: :ok
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
    __send__(cmd_handler)
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
    logger.debug "Validate XML request: #{request.raw_post}"
    Suse::Validator.validate(opt, LazyRequestReader.new(request))
  end

  def validate_xml_response
    return if @skip_validation

    request_format = request.format != 'json'
    response_status = response.status.to_s[0..2] == '200'
    response_headers = response.headers['Content-Type'] !~ %r{.*/json}i && response.headers['Content-Disposition'] != 'attachment'

    return unless request_format && response_status && response_headers

    opt = params
    opt[:method] = request.method.to_s
    opt[:type] = 'response'
    ms = Benchmark.ms do
      if response.body.respond_to?(:call)
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

  def shutup_rails
    Rails.cache.silence! unless Rails.env.development?
  end

  def set_nobody
    User.session = User.find_nobody!
  end

  def check_spider
    return request.bot? if Rails.env.production?

    false
  end

  def set_influxdb_data
    InfluxDB::Rails.current.tags = {
      beta: User.possibly_nobody.in_beta?,
      anonymous: !User.session,
      spider: check_spider,
      interconnect: false,
      interface: :api
    }
  end
end
