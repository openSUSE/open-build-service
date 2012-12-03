# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'frontend_compat'

class ApplicationController < ActionController::Base
  Rails.cache.set_domain if Rails.cache.respond_to?('set_domain');

  before_filter :check_mobile_views
  before_filter :instantiate_controller_and_action_names
  before_filter :set_return_to, :reset_activexml, :authenticate
  before_filter :check_user
  before_filter :require_configuration
  after_filter :validate_xhtml
  after_filter :clean_cache

  if Rails.env.test?
     prepend_before_filter :start_test_api
  end

  # FIXME: This belongs into the user controller my dear.
  # Also it would be better, but also more complicated, to just raise
  # HTTPPaymentRequired, UnauthorizedError or Forbidden
  # here so the exception handler catches it but what the heck...
  rescue_from ActiveXML::Transport::ForbiddenError do |exception|
    if exception.code == "unregistered_ichain_user"
      render :template => "user/request_ichain" and return
    elsif exception.code == "unregistered_user"
      render :file => "#{Rails.root}/public/403.html", :status => 402, :layout => false and return
    elsif exception.code == "unconfirmed_user"
      render :file => "#{Rails.root}/public/402.html", :status => 402, :layout => false
    else
      if @user
        render :file => "#{Rails.root}/public/403.html", :status => :forbidden, :layout => false 
      else
        render :file => "#{Rails.root}/public/401.html", :status => :unauthorized, :layout => false
      end
    end
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

  protected

  def set_return_to
    if params['return_to_host']
      @return_to_host = params['return_to_host']
    else
      # we have a proxy in front of us
      @return_to_host = CONFIG['external_webui_protocol'] || "http"
      @return_to_host += "://"
      @return_to_host += CONFIG['external_webui_host'] || request.host
    end
    @return_to_path = params['return_to_path'] || request.env['ORIGINAL_FULLPATH']
    logger.debug "Setting return_to: \"#{@return_to_path}\""
  end

  def require_login
    if !session[:login]
      render :text => 'Please login' and return if request.xhr?
      flash[:error] = "Please login to access the requested page."
      mode = :off
      mode = CONFIG['proxy_auth_mode'] unless CONFIG['proxy_auth_mode'].blank?
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
    mode = CONFIG['proxy_auth_mode'] unless CONFIG['proxy_auth_mode'].blank?
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
    mode = :off
    mode = CONFIG['proxy_auth_host'] unless CONFIG['proxy_auth_host'].blank?
    proxy_user = request.env['HTTP_X_USERNAME']
    proxy_user = CONFIG['proxy_test_user'] if mode == :simulate and CONFIG['proxy_test_user']
    proxy_email = request.env['HTTP_X_EMAIL']
    proxy_email = ICHAIN_TEST_EMAIL if mode == :simulate and ICHAIN_TEST_EMAIL
    if proxy_user
      session[:login] = proxy_user
      session[:email] = proxy_email
      # Set the headers for direct connection to the api, TODO: is this thread safe?
      ActiveXML::transport.set_additional_header( "X-Username", proxy_user )
      ActiveXML::transport.set_additional_header( "X-Email", proxy_email ) if proxy_email
    else
      session[:login] = nil
      session[:email] = nil
    end
  end

  def authenticate_form_auth
    if session[:login] and session[:password]
      # pass credentials to transport plugin, TODO: is this thread safe?
      ActiveXML::transport.login session[:login], session[:password]
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
    return true if name =~ /^_product:[-+\w\.:]*$/
    return true if name =~ /^_patchinfo:[-+\w\.:]*$/
    name =~ /^[[:alnum:]][-+\w\.:]*$/
  end

  def valid_package_name_write? name
    return true if name =~ /^_project$/
    return true if name =~ /^_product$/
    name =~ /^[[:alnum:]][-+\w\.]*$/
  end

  def valid_file_name? name
    name =~ /^[-\w+~ ][-\w\.+~ ]*$/
  end

  def valid_role_name? name
    name =~ /^[\w\-\.+]+$/
  end

  def valid_target_name? name
    name =~ /^\w[-\.\w&]*$/
  end

  def valid_user_name? name
    name =~ /^[\w\-\.+]+$/
  end

  def valid_group_name? name
    name =~ /^[\w\-\.+]+$/
  end

  def reset_activexml
    transport = ActiveXML::transport
    transport.delete_additional_header "X-Username"
    transport.delete_additional_header "X-Email"
    transport.delete_additional_header 'Authorization'
  end

  def required_parameters(*parameters)
    parameters.each do |parameter|
      unless params.include? parameter.to_s
        raise ActionController::RoutingError.new "Required Parameter #{parameter} missing"
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

  def find_cached(classname, *args)
    classname.free_cache( *args ) if discard_cache?
    classname.find_cached( *args )
  end

  def find_hashed(classname, *args)
    ret = classname.find_cached( *args )
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
        @nr_requests_that_need_work = 0
        unless request.xhr?
          @user.requests_that_need_work.each { |key,array| @nr_requests_that_need_work += array.size }
        end
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

  def put_body_to_tempfile(xmlbody)
    file = Tempfile.new('xml').path
    file = File.open(file + ".xml", "w")
    file.write(xmlbody)
    file.close
    return file.path
  end
  private :put_body_to_tempfile

  def validate_xhtml
    return if request.xhr?
    return unless (response.status.to_i == 200 && response.content_type =~ /text\/html/i)
    return if Rails.env.production? or Rails.env.stage?

    errors = []
    xmlbody = String.new response.body
    xmlbody.gsub!(/[\n\r]/, "\n")
    xmlbody.gsub!(/&[^;]*sp;/, '')
    
    # now to something fancy - patch HTML5 to look like xhtml 1.1
    xmlbody.gsub!(%r{ data-\S+=\"[^\"]*\"}, ' ')
    xmlbody.gsub!(%r{ autocomplete=\"[^\"]*\"}, ' ')
    xmlbody.gsub!(%r{ placeholder=\"[^\"]*\"}, ' ')
    xmlbody.gsub!('<!DOCTYPE html>', '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">')
    xmlbody.gsub!('<html>', '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">') 

    begin
      document = Nokogiri::XML::Document.parse(xmlbody, nil, nil, Nokogiri::XML::ParseOptions::STRICT)
    rescue Nokogiri::XML::SyntaxError => e
      errors << ("[%s:%s]" % [e.line, e.column]) + e.inspect
      errors << put_body_to_tempfile(xmlbody)
    end

    if document
      ses = XHTML_XSD.validate(document)
      unless ses.empty?
        document = nil
        errors << put_body_to_tempfile(xmlbody) 
        ses.each do |err|
          errors << ("[%s:%s]" % [err.line, err.column]) + err.inspect
        end
      end
    end

    unless document
      self.instance_variable_set(:@_response_body, nil)
      render :template => "xml_errors", :locals => { :oldbody => xmlbody, :errors => errors }, :status => 400
    end
  end

  @@frontend = nil
  def start_test_api
    return if @@frontend
    if ENV['API_STARTED']
      @@frontend = :dont
      return
    end
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
        response = ActiveXML::transport.direct_http(URI('/configuration.json'))
        ActiveSupport::JSON.decode(response)
      end
    rescue ActiveXML::Transport::NotFoundError
      logger.error 'Site configuration not found'
    rescue ActiveXML::Transport::UnauthorizedError
      @anonymous_forbidden = true
      logger.error 'Could not load all frontpage data, probably due to forbidden anonymous access in the api.'
    end
  end

  # Before filter to check if current user is administrator
  def require_admin
    if !@user || !@user.is_admin?
      flash[:error] = "Requires admin privileges"
      redirect_back_or_to :controller => 'main', :action => 'index' and return
    end
  end

  # After filter to clean up caches
  def clean_cache
    ActiveXML::Node.free_object_cache
  end

  def require_available_architectures
    @available_architectures = Architecture.find_cached(:available)
    unless @available_architectures
      flash[:error] = "Available architectures not found"
      redirect_to :controller => "project", :action => "list_public", :nextstatus => 404 and return
    end
  end

  def mobile_request?
    if params.has_key? :force_view
      # check if it's a reset
      if session[:force_view].to_s != 'mobile' && params[:force_view].to_s == 'mobile'
        session.delete :force_view 
      else
        session[:force_view] = params[:force_view]
      end
    end
    if session.has_key? :force_view
      if session[:force_view].to_s == 'mobile'
        request.env['mobile_device_type'] = :mobile
      else
        request.env['mobile_device_type'] = :forced_desktop
      end
    end
    unless request.env.has_key? 'mobile_device_type'
      if request.user_agent.nil? || request.env['HTTP_ACCEPT'].nil?
        request.env['mobile_device_type'] = :desktop
      else
        mobileesp = MobileESPConverted::UserAgentInfo.new(request.user_agent, request.env['HTTP_ACCEPT'])
        if mobileesp.is_tier_generic_mobile || mobileesp.is_tier_iphone || mobileesp.is_tier_rich_css || mobileesp.is_tier_tablet
          request.env['mobile_device_type'] = :mobile
        else
          request.env['mobile_device_type'] = :desktop
        end
      end
    end
    return request.env['mobile_device_type'] == :mobile
  end

  def check_mobile_views
    #prepend_view_path(Rails.root.join('app', 'mobile_views')) if mobile_request?
  end

  def check_ajax
    raise ActionController::RoutingError.new('Expected AJAX call') unless request.xhr?
  end
end
