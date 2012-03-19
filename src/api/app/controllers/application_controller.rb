# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'opensuse/permission'
require 'opensuse/backend'
require 'opensuse/validator'
require 'xpath_engine'
require 'rexml/document'

class InvalidHttpMethodError < Exception; end
class MissingParameterError < Exception; end
class InvalidParameterError < Exception; end

class ApplicationController < ActionController::Base

  # Do never use a layout here since that has impact on every controller
  layout nil
  # session :disabled => true

  @user_permissions = nil
  @http_user = nil

  helper RbacHelper

  before_filter :validate_incoming_xml, :add_api_version

  if Rails.env.test?
    before_filter :start_test_backend
  end

  # skip the filter for the user stuff
  before_filter :extract_user, :except => :register
  before_filter :setup_backend, :add_api_version, :restrict_admin_pages
  before_filter :shutup_rails
  before_filter :validate_params

  #contains current authentification method, one of (:ichain, :basic)
  attr_accessor :auth_method
  
  hide_action :auth_method
  hide_action 'auth_method='

  @@backend = nil
  def start_test_backend
    return if @@backend
    logger.debug "Starting test backend..."
    @@backend = IO.popen("#{RAILS_ROOT}/script/start_test_backend")
    logger.debug "Test backend started with pid: #{@@backend.pid}"
    while true do
      line = @@backend.gets
      raise RuntimeError.new('Backend died') unless line
      break if line =~ /DONE NOW/
      logger.debug line.strip
    end
    ActiveXML::Config.global_write_through = true
    at_exit do
      logger.debug "kill #{@@backend.pid}"
      Process.kill "INT", @@backend.pid
      @@backend = nil
    end
  end
  hide_action :start_test_backend

  protected
  def restrict_admin_pages
     if params[:controller] =~ /^active_rbac/ or params[:controller] =~ /^admin/
        return require_admin
     end
  end

  def require_admin
    logger.debug "Checking for  Admin role for user #{@http_user.login}"
    unless @http_user.has_role? 'Admin'
      logger.debug "not granted!"
      render :template => 'permerror'
      return false
    end
    return true
  end

  def validate_params
    params.each do |p|
      if not p[1].nil? and p[1].class != String
        raise InvalidParameterError, "Parameter #{p[0]} has non String class #{p[1].class}"
      end
    end
  end

  def extract_user
    if ICHAIN_MODE == :on || ICHAIN_MODE == :simulate # configured in the the environment file
      @auth_method = :ichain
      ichain_user = request.env['HTTP_X_USERNAME']
      if ichain_user
        logger.info "iChain user extracted from header: #{ichain_user}"
      elsif ICHAIN_MODE == :simulate
        ichain_user = ICHAIN_TEST_USER
        logger.debug "iChain user extracted from config: #{ichain_user}"
      end

      # we're using iChain, there is no need to authenticate the user from the credentials
      # However we have to care for the status of the user that must not be unconfirmed or ichain requested
      if ichain_user
        @http_user = User.find :first, :conditions => [ 'login = ? AND state=2', ichain_user ]
        @http_user.update_user_info_from_ichain_env(request.env) unless @http_user.nil?

        # If we do not find a User here, we need to create a user and wait for
        # the confirmation by the user and the BS Admin Team.
        if @http_user == nil
          @http_user = User.find :first, :conditions => ['login = ?', ichain_user ]
          if @http_user == nil
            render_error :message => "iChain user not yet registered", :status => 403,
              :errorcode => "unregistered_ichain_user",
              :details => "Please register your user via the web application #{CONFIG['webui_url']} once."
          else
            if @http_user.state == 5 or @http_user.state == 1
              render_error :message => "iChain user #{ichain_user} is registered but not yet approved.", :status => 403,
                :errorcode => "registered_ichain_but_unapproved",
                :details => "<p>Your account is a registered iChain account, but it is not yet approved for the buildservice.</p>"+
                "<p>Please stay tuned until you get approval message.</p>"
            else
              render_error :message => "Your user is either invalid or net yet confirmed (state #{@http_user.state}).",
                :status => 403,
                :errorcode => "unconfirmed_user",
                :details => "Please contact the openSUSE admin team <admin@opensuse.org>"
            end
          end
          return false
        end
      else
        if CONFIG['allow_anonymous']
          @http_user = User.find_by_login( "_nobody_" )
          @user_permissions = Suse::Permission.new( @http_user )
          return true
        end
        logger.error "No X-username header from iChain! Are we really using iChain?"
        render_error( :message => "No iChain user found!", :status => 401 ) and return false
      end
    else
      #active_rbac is used for authentication
      @auth_method = :basic

      if request.env.has_key? 'X-HTTP_AUTHORIZATION'
        # try to get it where mod_rewrite might have put it
        authorization = request.env['X-HTTP_AUTHORIZATION'].to_s.split
      elsif request.env.has_key? 'Authorization'
        # for Apace/mod_fastcgi with -pass-header Authorization
        authorization = request.env['Authorization'].to_s.split
      elsif request.env.has_key? 'HTTP_AUTHORIZATION'
        # this is the regular location
        authorization = request.env['HTTP_AUTHORIZATION'].to_s.split
      end

      logger.debug( "AUTH: #{authorization}" )

      if authorization and authorization[0] == "Basic"
        # logger.debug( "AUTH2: #{authorization}" )
        login, passwd = Base64.decode64(authorization[1]).split(':')[0..1]

        #set password to the empty string in case no password is transmitted in the auth string
        passwd ||= ""
      else
        if @http_user.nil? and CONFIG['allow_anonymous'] and CONFIG['webui_host'] and [ request.env['REMOTE_HOST'], request.env['REMOTE_ADDR'] ].include?( CONFIG['webui_host'] ) and request.env['HTTP_USER_AGENT'].match(/^obs-webui/)
          @http_user = User.find_by_login( "_nobody_" )
          @user_permissions = Suse::Permission.new( @http_user )
          return true
        else
          if @http_user.nil? and login
            render_error :message => "User not yet registered", :status => 403,
              :errorcode => "unregistered_user",
              :details => "Please register your user via the web application #{CONFIG['webui_url']} once."
            return false
          end
        end
        logger.debug "no authentication string was sent"
        render_error( :message => "Authentication required", :status => 401 ) and return false
      end

      # disallow empty passwords to prevent LDAP lockouts
      if !passwd or passwd == ""
        render_error( :message => "User '#{login}' did not provide a password", :status => 401 ) and return false
      end

      if defined?( LDAP_MODE ) && LDAP_MODE == :on
        begin
          require 'ldap'
          logger.debug( "Using LDAP to find #{login}" )
          ldap_info = User.find_with_ldap( login, passwd )
        rescue LoadError
          logger.debug "LDAP_MODE selected but 'ruby-ldap' module not installed."
          ldap_info = nil # now fall through as if we'd not found a user
        rescue Exception
          logger.debug "#{login} not found in LDAP."
          ldap_info = nil # now fall through as if we'd not found a user          
        end

        if not ldap_info.nil?
          # We've found an ldap authenticated user - find or create an OBS userDB entry.
          @http_user = User.find_by_login( login )
          if @http_user
            # Check for ldap updates
            if @http_user.email != ldap_info[0]
              @http_user.email = ldap_info[0]
              @http_user.save
            end
          else
            logger.debug( "No user found in database, creating" )
            logger.debug( "Email: #{ldap_info[0]}" )
            logger.debug( "Name : #{ldap_info[1]}" )
            # Generate and store a fake pw in the OBS DB that no-one knows
            chars = ["A".."Z","a".."z","0".."9"].collect { |r| r.to_a }.join
            fakepw = (1..24).collect { chars[rand(chars.size)] }.pack("C*")
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
              render_error( :message => "Cannot create ldap userid: '#{login}' on OBS<br>#{errstr}",
                :status => 401 )
              @http_user=nil
              return false
            end
            newuser.realname = ldap_info[1]
            newuser.state = User.states['confirmed']
            newuser.adminnote = "User created via LDAP"
            user_role = Role.find_by_title("User")
            newuser.roles << user_role

            logger.debug( "saving new user..." )
            newuser.save

            @http_user = newuser
          end

          session[:rbac_user_id] = @http_user.id
        else
          logger.debug( "User not found with LDAP, falling back to database" )
          @http_user = User.find_with_credentials login, passwd
        end

      else
        @http_user = User.find_with_credentials login, passwd
      end
    end

    if @http_user.nil?
      render_error( :message => "Unknown user '#{login}' or invalid password", :status => 401 ) and return false
    else
      if @http_user.state == 5 or @http_user.state == 1
        render_error :message => "User is registered but not yet approved.", :status => 403,
          :errorcode => "unconfirmed_user",
          :details => "<p>Your account is a registered account, but it is not yet approved for the OBS by admin.</p>"
        return false
      end

      if @http_user.state == 2
        logger.debug "USER found: #{@http_user.login}"
        @user_permissions = Suse::Permission.new( @http_user )
        return true
      end
    end

    render_error :message => "User is registered but not in confirmed state.", :status => 403,
      :errorcode => "inactive_user",
      :details => "<p>Your account is a registered account, but it is in a not active state.</p>"
    return false
  end

  hide_action :setup_backend  
  def setup_backend
    # initialize backend on every request
    Suse::Backend.source_host = SOURCE_HOST
    Suse::Backend.source_port = SOURCE_PORT
  end

  hide_action :add_api_version
  def add_api_version
    response.headers["X-Opensuse-APIVersion"] = "#{CONFIG['version']}"
  end

  hide_action :forward_from_backend
  def forward_from_backend(path)

    # apache & mod_xforward case
    if CONFIG['use_xforward'] and CONFIG['use_xforward'] != "false"
      logger.debug "[backend] VOLLEY(mod_xforward): #{path}"
      headers['X-Forward'] = "http://#{SOURCE_HOST}:#{SOURCE_PORT}#{path}"
      head(200)
      return
    end

    # lighttpd 1.5 case
    if CONFIG['x_rewrite_host']
      logger.debug "[backend] VOLLEY(lighttpd): #{path}"
      headers['X-Rewrite-URI'] = path
      headers['X-Rewrite-Host'] = CONFIG['x_rewrite_host']
      head(200)
      return
    end

    logger.debug "[backend] VOLLEY: #{path}"
    backend_http = Net::HTTP.new(SOURCE_HOST, SOURCE_PORT)
    backend_http.read_timeout = 1000

    file = Tempfile.new 'volley'
    type = nil

    opts = { :url_based_filename => true }
    
    backend_http.request_get(path) do |res|
      opts[:status] = res.code
      opts[:type] = res['Content-Type']
      res.read_body do |segment|
        file.write(segment)
      end
    end
    opts[:length] = file.length
    # streaming makes it very hard for test cases to verify output
    opts[:stream] = false if Rails.env.test?
    send_file(file.path, opts)
    file.close
  end

  hide_action :download_request
  def download_request
    file = Tempfile.new 'volley'
    b = request.body
    buffer = String.new
    while b.read(40960, buffer)
      file.write(buffer)
    end
    file.close
    file.open
    file
  end

  def pass_to_backend( path = nil )
    unless path
      path = request.path+'?'+request.query_string
    end

    case request.method
    when :get
      forward_from_backend( path )
      return
    when :post
      file = download_request
      response = Suse::Backend.post( path, file )
      file.close!
    when :put
      file = download_request
      response = Suse::Backend.put( path, file )
      file.close!
    when :delete
      response = Suse::Backend.delete( path )
    end

    send_data( response.body, :type => response.fetch( "content-type" ),
      :disposition => "inline" )
  end
  public :pass_to_backend

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

    case exception
    when Suse::Backend::HTTPError
      xml = REXML::Document.new( exception.message.body )
      http_status = xml.root.attributes['code']
      unless xml.root.attributes.include? 'origin'
        xml.root.add_attribute "origin", "backend"
      end
      xml_text = String.new
      xml.write xml_text
      render :text => xml_text, :status => http_status
    when ActiveXML::Transport::NotFoundError
      render_error :message => exception.message, :status => 404
    when Suse::ValidationError
      render_error :message => exception.message, :status => 400, :errorcode => 'validation_failed'
    when InvalidHttpMethodError
      render_error :message => exception.message, :errorcode => "invalid_http_method", :status => 400
    when DbPackage::SaveError
      render_error :message => "error saving package: #{exception.message}", :errorcode => "package_save_error", :status => 400
    when DbProject::SaveError
      render_error :message => "error saving project: #{exception.message}", :errorcode => "project_save_error", :status => 400
    when ActionController::RoutingError, ActiveRecord::RecordNotFound
      render_error :message => exception.message, :status => 404, :errorcode => "not_found"
    when ActionController::UnknownAction
      render_error :message => exception.message, :status => 403, :errorcode => "unknown_action"
    when ActionView::MissingTemplate
      render_error :message => exception.message, :status => 404, :errorcode => "not_found"
    when MissingParameterError
      render_error :status => 400, :message => exception.message, :errorcode => "missing_parameter"
    when InvalidParameterError
      render_error :status => 400, :message => exception.message, :errorcode => "invalid_parameter"
    when DbProject::CycleError
      render_error :status => 400, :message => exception.message, :errorcode => "project_cycle"
    else
      if send_exception_mail?
        ExceptionNotifier.deliver_exception_notification(exception, self, strip_sensitive_data_from(request), {})
      end
      render_error :message => "uncaught exception: #{exception.message}", :status => 400
    end
  end

  def send_exception_mail?
    return false unless ExceptionNotifier.exception_recipients
    return !local_request? && !Rails.env.development?
  end

  def permissions
    return @user_permissions
  end

  def user
    return @http_user
  end

  def required_parameters(*parameters)
    parameters.each do |parameter|
      unless params.include? parameter.to_s
        raise MissingParameterError, "Required Parameter #{parameter} missing"
      end
    end
  end

  def valid_http_methods(*methods)
    list = methods.map {|x| x.to_s.downcase.to_s}
    unless methods.include? request.method
      raise InvalidHttpMethodError, "Invalid HTTP Method: #{request.method.to_s.upcase}"
    end
  end

  def render_error( opt = {} )
    # workaround an exception in mod_rails, it dies when an answer is send without
    # reading the body. We trigger passenger to read the entire body via requesting the size
    if request.put? or request.post?
      request.body.size if request.body.respond_to? 'size'
    end

    if opt[:status]
      if opt[:status].to_i == 401
        response.headers["WWW-Authenticate"] = 'basic realm="API login"'
      end
    else
      opt[:status] = 400
    end

    @exception = opt[:exception]
    @details = opt[:details]

    @summary = "Internal Server Error"
    if opt[:message]
      @summary = opt[:message]
    elsif @exception
      @summary = @exception.message
    end

    if opt[:errorcode]
      @errorcode = opt[:errorcode]
    elsif @exception
      @errorcode = 'uncaught_exception'
    else
      @errorcode = 'unknown'
    end

    # if the exception was raised inside a template (-> @template.first_render != nil),
    # the instance variables created in here will not be injected into the template
    # object, so we have to do it manually
    # This is commented out, since it does not work with Rails 2.3 anymore and is also not needed there
    #    if @template.first_render
    #      logger.debug "injecting error instance variables into template object"
    #      %w{@summary @errorcode @exception}.each do |var|
    #        @template.instance_variable_set var, eval(var) if @template.instance_variable_get(var).nil?
    #      end
    #    end

    # on some occasions the status template doesn't receive the instance variables it needs
    # unless render_to_string is called before (which is an ugly workaround but I don't have any
    # idea where to start searching for the real problem)
    render_to_string :template => 'status'

    logger.info "errorcode '#{@errorcode}' - #{@summary}"
    response.headers['X-Opensuse-Errorcode'] = @errorcode
    render :template => 'status', :status => opt[:status], :layout => false
  end

  def render_ok(opt={})
    # keep compatible to old call style
    opt = {:details => opt} if opt.kind_of? String

    @errorcode = "ok"
    @summary = "Ok"
    @details = opt[:details] if opt[:details]
    @data = opt[:data] if opt[:data]
    render :template => 'status', :status => 200, :layout => false
  end

  def backend
    @backend ||= ActiveXML::Config.transport_for :bsrequest
  end

  def backend_get( path )
    # TODO: check why not using SUSE:Backend::get
    backend.direct_http( URI(path) )
  end

  def backend_put( path, data )
    backend.direct_http( URI(path), :method => "PUT", :data => data )
  end

  def backend_post( path, data )
    backend.set_additional_header("Content-Length", data.size.to_s())
    response = backend.direct_http( URI(path), :method => "POST", :data => data )
    backend.delete_additional_header("Content-Length")
    return response
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
    unless params.has_key? opt[:cmd_param]
      render_error :status => 400, :errorcode => "missing_parameter'",
        :message => "missing parameter '#{opt[:cmd_param]}'"
      return
    end

    cmd_handler = "#{params[:action]}_#{params[opt[:cmd_param]]}"
    logger.debug "dispatch_command: trying to call method '#{cmd_handler}'"

    if not self.respond_to? cmd_handler, true
      render_error :status => 400, :errorcode => "unknown_command",
        :message => "Unknown command '#{params[opt[:cmd_param]]}' for path #{request.path}"
      return
    end

    __send__ cmd_handler
  end
  public :dispatch_command
  hide_action :dispatch_command

  def build_query_from_hash(hash, key_list=nil)
    key_list ||= hash.keys
    query = key_list.map do |key|
      if hash.has_key?(key)
        if hash[key].nil?
          # just a boolean argument ?
          [hash[key]].flatten.map {|x| "#{key}"}.join("&")
        else
          [hash[key]].flatten.map {|x| "#{key}=#{CGI.escape(hash[key].to_s)}"}.join("&")
        end
      end
    end

    if query.empty?
      return ""
    else
      return "?"+query.compact.join('&')
    end
  end

  def query_parms_missing?(*list)
    missing = Array.new
    for param in list
      missing << param unless params.has_key? param
    end

    if missing.length > 0
      render_error :status => 400, :errorcode => "missing_query_parameters",
        :message => "missing query parameters: #{missing.join ', '}"
    end
    return false
  end

  def min_votes_for_rating
    MIN_VOTES_FOR_RATING
  end

  private
  def shutup_rails
    Rails.cache.silence!
  end

  def action_fragment_key( options )
    # this is for customizing the path/filename of cached files (cached by the
    # action_cache plugin). here we want to include params in the filename
    par = params
    par.delete 'controller'
    par.delete 'action'
    pairs = []
    par.sort.each { |pair| pairs << pair.join('=') }
    url_for( options ).split('://').last + "/"+ pairs.join(',').gsub(' ', '-')
  end

end
