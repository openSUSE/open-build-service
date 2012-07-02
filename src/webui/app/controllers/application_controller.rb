# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  Rails.cache.set_domain if Rails.cache.respond_to?('set_domain');

  before_filter :instantiate_controller_and_action_names
  before_filter :set_return_to, :reset_activexml, :authenticate
  before_filter :check_user
  before_filter :require_configuration
  after_filter :set_charset
  after_filter :validate_xhtml
  after_filter :clean_cache
  has_mobile_views

  if Rails.env.test?
     prepend_before_filter :start_test_api
  end

  class InvalidHttpMethodError < Exception; end
  class MissingParameterError < Exception; end
  class ValidationError < Exception
    attr_reader :xml, :errors

    def message
      errors
    end

    def initialize( _xml, _errors )
      @xml = _xml
      @errors = _errors
    end
  end

  protected

  def set_return_to
    if params['return_to_host']
      @return_to_host = params['return_to_host']
    else
      # we have a proxy in front of us
      @return_to_host = Object.const_defined?(:EXTERNAL_WEBUI_PROTOCOL) ? EXTERNAL_WEBUI_PROTOCOL : "http"
      @return_to_host += "://"
      @return_to_host += Object.const_defined?(:EXTERNAL_WEBUI_HOST) ? EXTERNAL_WEBUI_HOST : request.host
    end
    @return_to_path = params['return_to_path'] || request.env['ORIGINAL_FULLPATH']
    logger.debug "Setting return_to: \"#{@return_to_path}\""
  end

  def set_charset
    if !request.xhr? && !headers.has_key?('Content-Type')
      headers['Content-Type'] = "text/html; charset=utf-8"
    end
  end

  def require_login
    if !session[:login]
      render :text => 'Please login' and return if request.xhr?
      flash[:error] = "Please login to access the requested page."
      mode = :off
      mode = ICHAIN_MODE if defined? ICHAIN_MODE
      mode = PROXY_AUTH_MODE if defined? PROXY_AUTH_MODE
      if (mode == :off)
        redirect_to :controller => :user, :action => :login, :return_to_host => @return_to_host, :return_to_path => @return_to_path
      else
        redirect_to :controller => :main, :return_to_host => @return_to_host, :return_to_path => @return_to_path
      end
    end
  end

  # sets session[:login] if the user is authenticated
  def authenticate
    mode = :off
    mode = ICHAIN_MODE if defined? ICHAIN_MODE
    mode = PROXY_AUTH_MODE if defined? PROXY_AUTH_MODE
    logger.debug "Authenticating with iChain mode: #{mode}"
    if mode == :on || mode == :simulate
      authenticate_ichain
    else
      authenticate_form_auth
    end
    if session[:login]
      logger.info "Authenticated request to \"#{@return_to_path}\" from #{session[:login]}"
    else
      logger.info "Anonymous request to #{@return_to_path}"
    end
  end

  def authenticate_ichain
    mode = :off
    mode = ICHAIN_MODE if defined? ICHAIN_MODE
    mode = PROXY_AUTH_HOST if defined? PROXY_AUTH_HOST
    ichain_user = request.env['HTTP_X_USERNAME']
    ichain_user = ICHAIN_TEST_USER if mode == :simulate and ICHAIN_TEST_USER
    ichain_email = request.env['HTTP_X_EMAIL']
    ichain_email = ICHAIN_TEST_EMAIL if mode == :simulate and ICHAIN_TEST_EMAIL
    if ichain_user
      session[:login] = ichain_user
      session[:email] = ichain_email
      # Set the headers for direct connection to the api, TODO: is this thread safe?
      transport = ActiveXML::Config.transport_for( :project )
      transport.set_additional_header( "X-Username", ichain_user )
      transport.set_additional_header( "X-Email", ichain_email ) if ichain_email
    else
      session[:login] = nil
      session[:email] = nil
    end
  end

  def authenticate_form_auth
    if session[:login] and session[:passwd]
      # pass credentials to transport plugin, TODO: is this thread safe?
      ActiveXML::Config.transport_for(:project).login session[:login], session[:passwd]
    end
  end

  def frontend
    FrontendCompat.new
  end

  def valid_project_name? name
    name =~ /^[[:alnum:]][-+\w.:]+$/
  end

  def valid_package_name_read? name
    return true if name == "_project"
    return true if name == "_product"
    return true if name == "_deltas"
    return true if name =~ /^_product:[-_+\w\.:]*$/
    return true if name =~ /^_patchinfo:[-_+\w\.:]*$/
    name =~ /^[[:alnum:]][-_+\w\.:]*$/
  end

  def valid_package_name_write? name
    return true if name =~ /^_project$/
    return true if name =~ /^_product$/
    name =~ /^[[:alnum:]][-_+\w\.]*$/
  end

  def valid_file_name? name
    name =~ /^[-\w_+~ ][-\w_\.+~ ]*$/
  end

  def valid_role_name? name
    name =~ /^[\w\-_\.+]+$/
  end

  def valid_target_name? name
    name =~ /^\w[-_\.\w&]*$/
  end

  def valid_user_name? name
    name =~ /^[\w\-_\.+]+$/
  end

  def valid_group_name? name
    name =~ /^[\w\-_\.+]+$/
  end

  def reset_activexml
    transport = ActiveXML::Config.transport_for(:project)
    transport.delete_additional_header "X-Username"
    transport.delete_additional_header "X-Email"
    transport.delete_additional_header 'Authorization'
  end

  def strip_sensitive_data_from(request)
    # Strip HTTP_AUTHORIZATION header that contains the user's password
    # try to get it where mod_rewrite might have put it
    request.env["X-HTTP_AUTHORIZATION"] = "STRIPPED" if request.env.has_key? "X-HTTP_AUTHORIZATION"
    # for Apace/mod_fastcgi with -pass-header Authorization
    request.env["Authorization"] = "STRIPPED" if request.env.has_key? "Authorization"
    # this is the regular location
    request.env["HTTP_AUTHORIZATION"] = "STRIPPED" if request.env.has_key? "HTTP_AUTHORIZATION"
    return request
  end
  private :strip_sensitive_data_from

  def rescue_action_locally( exception )
    rescue_action_in_public( exception )
  end

  def rescue_action_in_public( exception )
    logger.error "rescue_action: caught #{exception.class}: #{exception.message}"
    message, code, api_exception = ActiveXML::Transport.extract_error_message exception

    case exception
    when ActionController::RoutingError
      render_error :status => 404, :message => "no such route"
    when ActionController::UnknownAction
      render_error :status => 404, :message => "unknown action"
    when ActiveXML::Transport::ForbiddenError
      # switch to registration on first access
      if code == "unregistered_ichain_user"
        render :template => "user/request_ichain" and return
      elsif code == "unregistered_user"
        render :template => "user/login" and return
      elsif code == "unconfirmed_user"
        render :template => "user/unconfirmed" and return
      else
        #ExceptionNotifier.deliver_exception_notification(exception, self, strip_sensitive_data_from(request), {}) if send_exception_mail?
        if @user
          render_error :status => 403, :message => message
        else
          render_error :status => 401, :message => message
        end
      end
    when ActiveXML::Transport::UnauthorizedError
      #ExceptionNotifier.deliver_exception_notification(exception, self, strip_sensitive_data_from(request), {}) if send_exception_mail?
      render_error :status => 401, :message => 'Unauthorized access, please login'
    when ActionController::InvalidAuthenticityToken
      render_error :status => 401, :message => 'Invalid authenticity token'
    when ActiveXML::Transport::ConnectionError
      render_error :message => "Unable to connect to API host. (#{FRONTEND_HOST})", :status => 503
    when Timeout::Error
      render :template => "timeout" and return
    when ValidationError
      ExceptionNotifier.deliver_exception_notification(exception, self, strip_sensitive_data_from(request), {}) if send_exception_mail?
      render :template => "xml_errors", :locals => { :oldbody => exception.xml, :errors => exception.errors }, :status => 400
    when MissingParameterError 
      render_error :status => 400, :message => message
    when InvalidHttpMethodError
      render_error :message => "Invalid HTTP method used", :status => 400
    when Net::HTTPBadResponse
      # The api sometimes sends responses without a proper "Status:..." line (when it restarts?)
      render_error :message => "Unable to connect to API host. (#{FRONTEND_HOST})", :status => 503
    else
      if code != 404 && send_exception_mail?
        ExceptionNotifier.deliver_exception_notification(exception, self, strip_sensitive_data_from(request), {})
      end
      render_error :status => 400, :code => code, :message => message,
        :exception => exception, :api_exception => api_exception
    end
  end

  def render_error( opt={} )
    # workaround an exception in mod_rails, it dies when an answer is send without
    # reading the body. We trigger passenger to read the entire body via requesting the size
    if request.put? or request.post?
      request.body.size if request.body.respond_to? 'size'
    end

    # :code is a string that comes from the api, :status is the http status code
    @status = opt[:status] || 400
    @code = opt[:code] || @status
    @message = opt[:message] || "No message set"
    @exception = opt[:exception] if show_detailed_exceptions?
    @api_exception = opt[:api_exception] if show_detailed_exceptions?
    logger.debug "ERROR: #{@code}; #{@message}"
    if request.xhr?
      render :text => @message, :status => @status, :layout => false
    else
      render :template => 'error', :status => @status, :locals => {:code => @code, :message => @message,
        :exception => @exception, :status => @status, :api_exception => @api_exception }
    end
  end

  def valid_http_methods(*methods)
    methods.map! {|x| x.to_s.upcase}
    unless methods.include? request.method
      raise InvalidHttpMethodError, "Invalid HTTP Method: #{request.method}"
    end
  end

  def required_parameters(*parameters)
    parameters.each do |parameter|
      unless params.include? parameter.to_s
        raise MissingParameterError, "Required Parameter #{parameter} missing"
      end
    end
  end

  def discard_cache?
    cc = request.headers['Cache-Control']
    return false if cc.blank?
    return true if cc == 'max-age=0'
    return false unless cc == 'no-cache'
    return !request.xhr?
  end

  def find_cached(classname, *args)
    classname.free_cache( *args ) if discard_cache?
    classname.find_cached( *args )
  end

  def find_hashed(classname, *args)
    ret = classname.find_cached( *args )
    return {} unless ret
    ret.to_hash
  end

  def send_exception_mail?
    return !show_detailed_exceptions? && !Rails.env.development? && ExceptionNotifier.exception_recipients && ExceptionNotifier.exception_recipients.length > 0
  end

  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
  end

  def check_spiders
    @spider_bot = false
    if defined? TREAT_USER_LIKE_BOT or request.env.has_key? 'HTTP_OBS_SPIDER'
      @spider_bot = true
      return
    end
  end
  private :check_spiders

  def lockout_spiders
    check_spiders
    if @spider_bot
       render :nothing => true
       return true
    end
    return false
  end

  def check_user
    check_spiders
    return unless session[:login]
    if discard_cache?
      Rails.cache.delete("person_#{session[:login]}")
      Person.free_cache(session[:login])
    end
    @user ||= Person.find_cached(session[:login], :is_current => true)
    if @user
      Rails.cache.set_domain(@user.to_s) if Rails.cache.respond_to?('set_domain');
      begin
        @nr_requests_that_need_work = @user.requests_that_need_work(:cache => !discard_cache?).flatten.size
      rescue Timeout::Error
        # TODO: add all temporary errors here, but no catch all
      end
    end
  end

  def map_to_workers(arch)
    case arch
    when 'i586' then 'x86_64'
    when 'ppc' then 'ppc64'
    when 's390' then 's390x'
    else arch
    end
  end
 
  private

  def assert_xml_validates
  end

  def put_body_to_tempfile(xmlbody)
    file = Tempfile.new('xml').path
    file = File.open(file + ".xml", "w")
    file.write(xmlbody)
    file.close
    return file.path
  end
  private :put_body_to_tempfile

  def validate_xhtml
    return if Rails.env.production? or Rails.env.stage?
    return if request.xhr?
    return if mobile_request?
    return if !(response.status =~ /200/ && response.headers['Content-Type'] =~ /text\/html/i)

    errors = []
    xmlbody = String.new response.body
    xmlbody.gsub!(/[\n\r]/, "\n")
    xmlbody.gsub!(/&[^;]*sp;/, '')
    
    begin
      document = Nokogiri::XML::Document.parse(xmlbody, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    rescue Nokogiri::XML::SyntaxError => e
      errors << e.inspect
      errors << put_body_to_tempfile(xmlbody)
    end

    if document
      ses = XHTML_XSD.validate(document)
      unless ses.empty?
        document = nil
        errors << put_body_to_tempfile(xmlbody) 
        ses.each do |e|
          errors << e.inspect
        end
      end
    end

    unless document
      erase_render_results
      raise ValidationError.new xmlbody, errors
    end
  end

  @@frontend = nil
  def start_test_api
    return if @@frontend
    @@frontend = IO.popen(Rails.root.join('script', 'start_test_api').to_s)
    puts "Starting test API with pid: #{@@frontend.pid}"
    lines = []
    while true do
      line = @@frontend.gets
      unless line
        puts lines.join()
        raise RuntimeError.new('Frontend died')
      end
      break if line =~ /Test API ready/
      lines << line
    end
    puts "Test API up and running with pid: #{@@frontend.pid}"
    at_exit do
       puts "Killing test API with pid: #{@@frontend.pid}"
       Process.kill "INT", @@frontend.pid
       @@frontend = nil
    end
  end

  def require_configuration
    @configuration = {}
    begin
      @configuration = Rails.cache.fetch('configuration', :expires_in => 30.minutes) do
        response = ActiveXML::Config::transport_for(:configuration).direct_http(URI('/configuration.json'))
        ActiveSupport::JSON.decode(response)
      end
    rescue ActiveXML::Transport::NotFoundError
      logger.error 'Site configuration not found'
    rescue ActiveXML::Transport::UnauthorizedError => e
      @anonymous_forbidden = true
      logger.error 'Could not load all frontpage data, probably due to forbidden anonymous access in the api.'
    end
  end

  # Before filter to check if current user is administrator
  def require_admin
    if @user and not @user.is_admin?
      flash[:error] = "Requires admin privileges"
      redirect_back_or_to :controller => 'main', :action => 'index' and return
    end
  end

  # After filter to clean up caches
  def clean_cache
    ActiveXML::Base.free_object_cache
  end

  def require_available_architectures
    @available_architectures = Architecture.find_cached(:available)
    unless @available_architectures
      flash[:error] = "Available architectures not found"
      redirect_to :controller => "project", :action => "list_public", :nextstatus => 404 and return
    end
  end

end
