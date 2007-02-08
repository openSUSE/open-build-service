# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

# RAILS_ROOT is not working directory when running under lighttpd, so it has
# to be added to load path
$LOAD_PATH.unshift RAILS_ROOT
# 
require_dependency 'opensuse/permission'
require_dependency 'opensuse/backend'
require_dependency 'opensuse/validator'
require_dependency 'xpath_engine'
require_dependency 'user'

class ApplicationController < ActionController::Base
  # Do never use a layout here since that has impact on every
  # controller in frontend.

  session_options[:prefix] = "ruby_frontend_sess."
  session_options[:session_key] = "opensuse_frontend_session"
  @user_permissions = nil
  @http_user = nil
  
  #session options for tag admin
  session_options[:sort] ||= "ASC"
  session_options[:column] ||= "id"
  
  helper RbacHelper
  
  # skip the filter for the user stuff
  before_filter :extract_user, :except => :register
  before_filter :setup_backend, :add_api_version

  #contains current authentification method, one of (:ichain, :basic_auth)
  attr_accessor :auth_method


  def extract_user
    @http_user = nil;

    if ichain_mode != :off # configured in the the environment file
      auth_method = :ichain

      logger.debug "configured iChain mode: #{ichain_mode.to_s},  remote_ip: #{request.remote_ip()}"

      ichain_user = request.env['HTTP_X_USERNAME']

      if ichain_user 
        logger.debug "iChain user extracted from header: #{ichain_user}"
      else
# TEST vv
        if ichain_mode == :simulate
          ichain_user = ichain_test_user 
          logger.debug "TEST-ICHAIN_USER #{ichain_user} set!"
        end
        request.env.each do |name, val|
          logger.debug "Header value: #{name} = #{val}"
        end
# TEST ^^
      end
      # ok, we're using iChain. So there is no need to really
      # authenticate the user from the credentials coming via
      # basic auth header field. We can trust the username coming from
      # iChain
      # However we have to care for the status of the user that must not be
      # unconfirmed or ichain requested
      if ichain_user 
        @http_user = User.find :first,
                                 :conditions => [ 'login = ? AND state=2', ichain_user ]
                                 
      # If we do not find a User here, we need to create a user and wait for 
      # the confirmation by the user and the BS Admin Team.
        if @http_user == nil 
          @http_user = User.find :first, 
                                   :conditions => ['login = ?', ichain_user ]
          if @http_user == nil 
            render_error :message => "iChain user not yet registered", :status => 403,
                         :errorcode => "unregistered_ichain_user",
                         :details => "Please register your iChain user via the web application once."
          else
            if @http_user.state == 5
              render_error :message => "iChain user #{ichain_user} is registered but not yet approved.", :status => 403,
                           :errorcode => "registered_ichain_but_unapproved",
                           :details => "<p>Your account is a registered iChain account, but it is not yet approved for the buildservice.</p>"+
                                       "<p>Please stay tuned until you get approval message.</p>"
            else
              render_error :message => "Your user is either invalid or net yet confirmned (state #{@http_user.state}).", 
                           :status => 403,
                           :errorcode => "unconfirmed_user",
                           :details => "Please contact the openSUSE admin team"
            end
          end
          return false
        end
      else
        logger.error "No X-username header from iChain! Are we really using iChain?"
        render_error( :message => "No iChain user found!", :status => 401 ) and return false
      end
    else 
      #active_rbac is used for authentication
      auth_method = :active_rbac

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
        logger.debug "no authentication string was sent"
        render_error( :message => "Authentication required", :status => 401 ) and return false
      end
      @http_user = User.find_with_credentials login, passwd
    end

    if @http_user.nil?
      render_error( :message => "Unknown user '#{login}' or invalid password", :status => 401 ) and return false
    else
      logger.debug "USER found: #{@http_user.login}"
      @user_permissions = Suse::Permission.new( @http_user )
    end
  end

  def setup_backend
    # initialize backend on every request
    Suse::Backend.source_host = SOURCE_HOST
    Suse::Backend.source_port = SOURCE_PORT
    Suse::Backend.rpm_host = RPM_HOST
    Suse::Backend.rpm_port = RPM_PORT
    
    if @http_user
      if @http_user.source_host && !@http_user.source_host.empty?
        Suse::Backend.source_host = @http_user.source_host
      end

      if @http_user.source_port
        Suse::Backend.source_port = @http_user.source_port
      end

      if @http_user.rpm_host && !@http_user.rpm_host.empty?
        Suse::Backend.rpm_host = @http_user.rpm_host
      end

      if @http_user.rpm_port
        Suse::Backend.rpm_port = @http_user.rpm_port
      end
      
      logger.debug "User's source backend <#{@http_user.source_host}:#{@http_user.source_port}>, rpm backend: <#{@http_user.rpm_host}:#{@http_user.rpm_port}>"
    end
  end

  def add_api_version
    @response.headers["X-Opensuse-APIVersion"] = API_VERSION
  end

  def forward_data( path, opt={} )
    defaults = {:server => :source, :method => :get}
    opt = defaults.merge opt

    if opt[:server] == :source
      case opt[:method]
      when :get
        response = Suse::Backend.get_source( path )
      when :post
        response = Suse::Backend.post_source( path, @request.raw_post )
      when :put
        response = Suse::Backend.put_source( path, @request.raw_post )
      end
    elsif opt[:server] == :repo
      case opt[:method]
      when :get
        response = Suse::Backend.get_rpm( path )
      when :post
        response = Suse::Backend.post_rpm( path, @request.raw_post )
      when :put
        response = Suse::Backend.post_rpm( path, @request.raw_post )
      end
    else
      raise "illegal server type: #{opt[:server].inspect}"
    end

    send_data( response.body, :type => response.fetch( "content-type" ),
      :disposition => "inline" )
  end

  def rescue_action_in_public( exception )
    #FIXME: not all exceptions are caught by this method
    case exception
    when ::Suse::Backend::HTTPError
      response = exception.message
      case response
    when Net::HTTPForbidden
      message = "Permission Denied"
    else
      message = "Backend Error: #{response.code}"
    end
      render_error :message => message, :status => response.code,
        :details => response.body
      return true
    when ActiveXML::Transport::NotFoundError
      render_error :message => exception.message, :status => 404
      return
    end
    render_error :exception => exception
  end

  def local_request?
    false
  end

  def permissions
    return @user_permissions
  end

  def user
    return @http_user
  end

  def render_error( opt = {} )
    if opt[:status]
      if opt[:status].to_i == 401
        response.headers["WWW-Authenticate"] = 'basic realm="Frontend login"'
      end
    else
      opt[:status] = 500
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
    if @template.first_render
      logger.debug "injecting error instance variables into template object"
      %w{@summary @errorcode @exception}.each do |var|
        @template.instance_variable_set var, eval(var) if @template.instance_variable_get(var).nil?
      end
    end

    # on some occasions the status template doesn't receive the instance variables it needs
    # unless render_to_string is called before (which is an ugly workaround but I don't have any
    # idea where to start searching for the real problem)
    render_to_string :template => 'status'

    logger.info "errorcode '#@errorcode' - #@summary"
    render :template => 'status', :status => opt[:status], :layout => false
  end
  
  def render_ok
    @errorcode = "ok"
    @summary = "Ok"
    render :template => 'status', :status => 200, :layout => false
  end
  
  def require_admin
    logger.debug "Checking for  Admin role for user #{@http_user.login}"
    unless @http_user.has_role( 'Admin' )
      logger.debug "not granted!"
      render :template => 'permerror'
    end
  end

  def backend
    @backend ||= ActiveXML::Config.transport_for :packstatus
  end

  def backend_get( path )
    backend.direct_http( URI(path) )
  end

  def backend_put( path, data )
    backend.direct_http( URI(path), :method => "PUT", :data => data )
  end

  #default actions, passes data from backend
  def pass_to_repo
    forward_data @request.path+'?'+@request.query_string, :server => :repo
  end

  def pass_to_source
    forward_data @request.path+'?'+@request.query_string, :server => :source
  end

  def ichain_mode
      ICHAIN_MODE
  end
  
  def ichain_test_user
      ICHAIN_TEST_USER
  end
end
