# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

# RAILS_ROOT is not working directory when running under lighttpd, so it has
# to be added to load path
$LOAD_PATH.unshift RAILS_ROOT
# 
require_dependency 'opensuse/permission'
require_dependency 'opensuse/backend'
require_dependency 'opensuse/validator'
require_dependency 'bsuser'

class ApplicationController < ActionController::Base
  # Do never use a layout here since that has impact on every
  # controller in frontend.

  session_options[:prefix] = "ruby_frontend_sess."
  session_options[:session_key] = "opensuse_frontend_session"
  @user_permissions = nil
  @http_user = nil
  
  helper RbacHelper
  
  before_filter :extract_user, :setup_backend, :validate


  def extract_user
    @http_user = nil;

    logger.debug( "Remote IP: #{request.remote_ip()}" )

    if ichain_host  # configured in the the environment file
      logger.debug "Have an iChain host: #{ichain_host}"
      ichain_user = request.env['HTTP_X_USERNAME']
      if ichain_user 
        logger.debug "iChain user extracted from header: #{ichain_user}"
      else
# TEST vv
        ichain_user = "freitag"
        logger.debug "TEST-ICHAIN_USER freitag set!"
        request.env.each do |name, val|
          logger.debug "Header value: #{name} = #{val}"
        end
# TEST ^^
      end
      logger.debug "iChain-User from environment: #{ichain_user}"
      # ok, we're using iChain. So there is no need to really
      # authenticate the user from the credentials coming via
      # basic auth header field. We can trust the username coming from
      # iChain
      if ichain_user 
        @http_user = BSUser.find :first,
                                 :conditions => [ 'login = ?', ichain_user ]
      else
        logger.error "No X-username header from iChain! Are we really using iChain?"
      end
    else
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
      else
        logger.debug "no authentication string was sent"
        render_error( :message => "Authentication required", :status => 401 ) and return false
      end
      @http_user = BSUser.find_with_credentials login, passwd
    end

    if @http_user.nil?
      render_error( :message => "Unknown or invalid user: #{login}\n", :status => 401 ) and return false
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

  def validate
    return true unless request.put?
    Suse::Validator.new(params).validate(request.raw_post)
    true
  end

  def forward_data( path, opt={} )
    response = Suse::Backend.get( path )
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
    end
    render_error :exception => exception
  end

  def local_request?
    false
  end

  def permissions
    return @user_permissions
  end

  def render_error( opt = {} )
    @errorcode = 500

    if opt[:status]
      @errorcode = opt[:status]
      if @errorcode.to_i == 401
        response.headers["WWW-Authenticate"] = 'basic realm="Frontend login"'
      end
    end

    @summary = "Internal Server Error"
    if opt[:message]
      @summary = opt[:message]
    end
    
    if opt[:exception]
      @exception = opt[:exception ]
    end

    if opt[:details]
      @details = opt[:details]
    end

    render :template => 'status', :status => @errorcode, :layout => false
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
  
  def ichain_host
    # if self.class.const_defined? "ICHAIN_HOST"
      ICHAIN_HOST
    # end
    # nil
  end
end
