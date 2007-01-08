# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

#hack to autoload activexml and frontendcontroller on change
require_dependency 'activexml'
#require_dependency 'opensuse/frontend'
require_dependency 'frontend_compat'


class ApplicationController < ActionController::Base
  session_options[:prefix] = "ruby_webclient_sess."
  session_options[:key] = "opensuse_webclient_session"

  before_filter :authorize 
  
  #filter
  def authorize
    session[:return_to] ||= request.request_uri
    if ichain_mode == 'on' || ichain_mode == 'simulate'
      logger.debug "iChain mode: #{ichain_mode}"
      ichain_user = request.env['HTTP_X_USERNAME']
# TEST vv
      unless ichain_user
        if ichain_mode == 'simulate'
          ichain_user = ichain_test_user
          logger.debug "TEST-ICHAIN_USER #{ichain_user} set!"
        end
        request.env.each do |name, val|
          logger.debug "Header value: #{name} = #{val}"
        end
# TEST ^^
      else
        logger.debug "iChain-User from environment: #{ichain_user}"
      end

      if ichain_user
        logger.debug "Setting Session login to #{ichain_user}"
        @session[:login] = ichain_user
        # Do the transport
        transport = ActiveXML::Config.transport_for( :project )
        transport.set_additional_header( "X-Username", ichain_user )
    
        # set user object reachable from controller
        @user = Person.find( ichain_user )

      else
        redirect_to :controller => 'privacy', :action => 'ichain_login'
      end
    else
      basic_auth
    end
  end

  def basic_auth
    unless session[:login] 
      # We use our own authentication
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
      logger.debug "authorization: #{authorization}"
      
      if ( authorization and authorization.size == 2 and
           authorization[0] == "Basic" )
        logger.debug( "AUTH2: #{authorization[1]}" )
      
        login, passwd = Base64.decode64( authorization[1] ).split(/:/)
        if login and passwd
          session[:login] = login  
          session[:passwd] = passwd
        end
      end
    end
    
    unless session[:login] and session[:passwd]
      # if we still do not have a user in the session it's time to redirect.
      session[:return_to] = request.request_uri
      redirect_to :controller => 'user', :action => 'login'
      return
    end

    # pass credentials to transport plugin
    ActiveXML::Config.transport_for(:project).login session[:login], session[:passwd]
    
    # set user object reachable from controller
    @user = Person.find( session[:login] )
  end

  def rescue_action_in_public( exception )
    logger.debug "rescue_action_in_public: caught #{exception.class}: #{exception.message}"

    #try to parse error message
    begin
      api_error = REXML::Document.new( exception.message ).root
    rescue
    end

    if api_error and api_error.name == "status"
      @code = api_error.attributes['code']
      @message = api_error.elements['summary'].text
      @details = api_error.elements['details'].text if api_error.elements['details']
      @api_exception = api_error.elements['exception'] if api_error.elements['exception']
    else
      @code = 500
      @message = exception.message
      @exception = exception
    end

    case exception
    when ActiveXML::Transport::UnauthorizedError
      session[:login] = nil
      session[:passwd] = nil

      flash[:error] = @message

      redirect_to :controller => 'user', :action => 'login'
    when ActiveXML::Transport::ForbiddenError
      if @code == "unregistered_ichain_user" 
        redirect_to :controller => 'user', :action => 'request_ichain'
      else
        render_error :code => @code, :message => @message
      end
#   when ActiveXML::Transport::ConnectionError
#     render_error :code => @code, :message => @message
#   when ActiveXML::Error
#     render_error :code => @code, :message => @messag
    else
      # FIXME: This should be done in the ForbiddenError-Exception handling.
      # but the exception handling seems to be buggy atm
      if @code == "unregistered_ichain_user"
        redirect_to :controller => 'user', :action => 'request_ichain'
      else
        logger.debug "default exception handling"
        render_error :code => @code, :message => @message, :exception => @exception, :api_exception => @api_exception
      end
    end
  end

  def render_error( opt={} )
    @code = opt[:code] || 500
    @message = opt[:message] || "No message set"
    @exception_xml = opt[:exception_xml]
    @exception = opt[:exception]

    logger.debug "ERROR: #{@code} #{@error_message}"

    # if the exception was raised inside a template (-> @template.first_render != nil), 
    # the instance variables created in here will not be injected into the template
    # object, so we have to do it manually
    if @template.first_render
      logger.debug "injecting error instance variables into template object"
      %w{@message @code @exception_xml @exception}.each do |var|
        @template.instance_variable_set var, eval(var) if @template.instance_variable_get(var).nil?
      end
    end

    render :template => 'error', :status => @code
  end

  def local_request?
    false
  end

  def frontend
    if ( !@frontend )
      @frontend = FrontendCompat.new
    end
    @frontend
  end

  def ichain_mode
    ICHAIN_MODE
  end

  def ichain_test_user
      ICHAIN_TEST_USER
  end

  def valid_project_name? name
    name =~ /^\w[-_+\w\.:]+$/
  end

  def valid_package_name? name
    name =~ /^\w[-_+\w\.]+$/
  end

end
