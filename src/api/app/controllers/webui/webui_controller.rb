# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'frontend_compat'

class Webui::WebuiController < ActionController::Base
  Rails.cache.set_domain if Rails.cache.respond_to?('set_domain')

  before_filter :setup_view_path
  before_filter :instantiate_controller_and_action_names
  before_filter :set_return_to, :reset_activexml, :authenticate
  before_filter :check_user
  before_filter :require_configuration
  after_filter :clean_cache

  protect_from_forgery

  # We execute both strategies here. The default rails strategy (resetting the session)
  # and throwing an exception if the session is handled elswhere (e.g. proxy_auth_mode: :on)
  def handle_unverified_request
    super
    raise ActionController::InvalidAuthenticityToken
  end

  # :notice and :alert are default, we add :success and :error
  add_flash_types :success, :error

  # FIXME: This belongs into the user controller my dear.
  # Also it would be better, but also more complicated, to just raise
  # HTTPPaymentRequired, UnauthorizedError or Forbidden
  # here so the exception handler catches it but what the heck...
  rescue_from ActiveXML::Transport::ForbiddenError do |exception|
    if exception.code == 'unregistered_ichain_user'
      render template: 'user/request_ichain' and return
    elsif exception.code == 'unregistered_user'
      render file: Rails.root.join('public/403'), formats: [:html], status: 402, layout: false and return
    elsif exception.code == 'unconfirmed_user'
      render file: Rails.root.join('public/402'), formats: [:html], status: 402, layout: false
    else
      if User.current.is_nobody?
        render file: Rails.root.join('public/401'), formats: [:html], status: :unauthorized, layout: false
      else
        render file: Rails.root.join('public/403'), formats: [:html], status: :forbidden, layout: false
      end
    end
  end
  
  rescue_from ActionController::RedirectBackError do |exception|
    redirect_to root_path
  end

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

  class MissingParameterError < Exception; end
  rescue_from MissingParameterError do |exception|
    logger.debug "#{exception.class.name} #{exception.message} #{exception.backtrace.join('\n')}"
    render file: Rails.root.join('public/404'), status: 404, layout: false, formats: [:html]
  end

  protected

  def set_return_to
    if params['return_to_host']
      @return_to_host = params['return_to_host']
    else
      # we have a proxy in front of us
      @return_to_host = ::Configuration.first.obs_url
      unless @return_to_host
        # fetch old config value and store in db
        @return_to_host = CONFIG['external_webui_protocol'] || 'http'
        @return_to_host += '://'
        @return_to_host += CONFIG['external_webui_host'] || request.host
        f = ::Configuration.first
        f.obs_url = @return_to_host
        f.save
      end
    end
    @return_to_path = params['return_to_path'] || request.env['ORIGINAL_FULLPATH']
    logger.debug "Setting return_to: \"#{@return_to_path}\""
  end

  def require_login
    if User.current.is_nobody?
      render :text => 'Please login' and return false if request.xhr?
      flash[:error] = 'Please login to access the requested page.'
      mode = CONFIG['proxy_auth_mode'] || :off
      if mode == :off
        redirect_to :controller => :user, :action => :login, :return_to_host => @return_to_host, :return_to_path => @return_to_path
      else
        redirect_to :controller => :main, :return_to_host => @return_to_host, :return_to_path => @return_to_path
      end
      return false
    end
    return true
  end

  # sets session[:login] if the user is authenticated
  def authenticate
    mode = CONFIG['proxy_auth_mode'] || :off
    logger.debug "Authenticating with iChain mode: #{mode}"
    if mode == :on || mode == :simulate
      authenticate_proxy
    else
      authenticate_form_auth
    end
    if session[:login]
      logger.info "Authenticated request to \"#{@return_to_path}\" from #{session[:login]}"
    else
      logger.info "Anonymous request to #{@return_to_path}"
    end
  end

  def authenticate_proxy
    mode = CONFIG['proxy_auth_mode'] || :off
    proxy_user = request.env['HTTP_X_USERNAME']
    proxy_email = request.env['HTTP_X_EMAIL']
    if mode == :simulate
      proxy_user ||= CONFIG['proxy_auth_test_user'] || CONFIG['proxy_test_user']
      proxy_email ||= CONFIG['proxy_auth_test_email']
    end 
    if proxy_user
      session[:login] = proxy_user
      session[:email] = proxy_email
      # Set the headers for direct connection to the api, TODO: is this thread safe?
      ActiveXML::api.set_additional_header( 'X-Username', proxy_user )
      ActiveXML::api.set_additional_header( 'X-Email', proxy_email ) if proxy_email
      # FIXME: hot fix to allow new users to login at all again
      frontend.transport.direct_http(URI("/person/#{URI.escape(proxy_user)}"), :method => 'GET')
    else
      session[:login] = nil
      session[:email] = nil
    end
  end

  def authenticate_form_auth
    if session[:login] and session[:password]
      # pass credentials to transport plugin, TODO: is this thread safe?
      ActiveXML::api.login session[:login], session[:password]
    end
  end

  def frontend
    FrontendCompat.new
  end

  def reset_activexml
    transport = ActiveXML::api
    transport.delete_additional_header 'X-Username'
    transport.delete_additional_header 'X-Email'
    transport.delete_additional_header 'Authorization'
  end

  def required_parameters(*parameters)
    parameters.each do |parameter|
      unless params.include? parameter.to_s
        raise MissingParameterError.new "Required Parameter #{parameter} missing in #{request.url}"
      end
    end
  end

  def discard_cache?
    cc = request.headers['HTTP_CACHE_CONTROL']
    return false if cc.blank?
    return true if cc == 'max-age=0'
    return false unless cc == 'no-cache'
    return !request.xhr?
  end

  def find_hashed(classname, *args)
    ret = classname.find( *args )
    return Xmlhash::XMLHash.new({}) unless ret
    ret.to_hash
  end

  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
  end

  def check_spiders
    @spider_bot = false
    if defined? TREAT_USER_LIKE_BOT or request.env.has_key? 'HTTP_OBS_SPIDER'
      @spider_bot = true
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
    User.current = nil # reset old users hanging around
    if session[:login]
      User.current = User.find_by_login(session[:login])
    end
    # TODO: rebase on application_controller and use load_nobdy
    User.current ||= User.find_by_login('_nobody_')
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

  def put_body_to_tempfile(xmlbody)
    file = Tempfile.new('xml').path
    file = File.open(file + '.xml', 'w')
    file.write(xmlbody)
    file.close
    return file.path
  end
  private :put_body_to_tempfile

  def require_configuration
    @configuration = ::Configuration.first
  end

  # Before filter to check if current user is administrator
  def require_admin
    unless User.current.is_admin?
      flash[:error] = 'Requires admin privileges'
      redirect_back_or_to :controller => 'main', :action => 'index' and return
    end
  end

  # After filter to clean up caches
  def clean_cache
  end

  def require_available_architectures
    @available_architectures = Architecture.where(available: 1)
  end

  def setup_view_path
    if CONFIG['theme']
      theme_path = Rails.root.join('app', 'views', 'webui', 'theme', CONFIG['theme'])
      prepend_view_path(theme_path)
    end
  end

  def check_ajax
    raise ActionController::RoutingError.new('Expected AJAX call') unless request.xhr?
  end
end
