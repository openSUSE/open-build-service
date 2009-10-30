# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  
  before_filter :set_return_to, :reset_activexml, :authenticate
  # TODO: currently set for all pages but index, remove when we open up anon access
  before_filter :require_login
  after_filter :set_charset
  protect_from_forgery

  # Scrub sensitive parameters from your log
  filter_parameter_logging :password

  class InvalidHttpMethodError < Exception; end
  
  def min_votes_for_rating
    MIN_VOTES_FOR_RATING
  end

  def set_return_to
    # we cannot get the original protocol when behind lighttpd/apache
    @return_to_host = params['return_to_host'] || "https://" + request.host
    @return_to_path = params['return_to_path'] || request.env['REQUEST_URI']
    logger.debug "Setting return_to: #{@return_to_path}"
  end

  def set_charset
    unless request.xhr?
      headers['Content-Type'] = "text/html; charset=utf-8"
    end
  end


  def require_login
    if !session[:login]
      flash[:error] = "Please login to access the requested page."
      if (ICHAIN_MODE == 'off')
        redirect_to :controller => :user, :action => :login, :return_to_host => @return_to_host, :return_to_path => @return_to_path
      else
        redirect_to :controller => :main, :return_to_host => @return_to_host, :return_to_path => @return_to_path
      end
    end
  end


  # sets session[:login] if the user is authenticated
  def authenticate
    logger.debug "Authenticating with iChain mode: #{ICHAIN_MODE}"
    if ICHAIN_MODE == 'on' || ICHAIN_MODE == 'simulate'
      authenticate_ichain
    elsif request.env.has_key? 'X-HTTP_AUTHORIZATION' or request.env.has_key? 'Authorization' or
        request.env.has_key? 'HTTP_AUTHORIZATION'
      authenticate_basic_auth
    else
      authenticate_form_auth
    end
    if session[:login]
      begin
        @user = Person.find( session[:login] )
        logger.info "Authenticated request to #{@return_to_path} from #{session[:login]}"
      rescue Object => exception
        logger.info "Login to #{@return_to} failed for #{session[:login]}: #{exception}"
        case exception
        when ActiveXML::Transport::UnauthorizedError
          reset_session
          flash.now[:error] = "Authentication failed"
          render :template => "user/login", :locals => {}
        # show the welcome page on first login
        when ActiveXML::Transport::ForbiddenError
          render :template => "user/request_ichain" if !params[:register]
        end
      end
    else
      logger.info "Anonymous request to #{@return_to_path}"
    end
  end


  def authenticate_ichain
    ichain_user = request.env['HTTP_X_USERNAME']
    ichain_user = ICHAIN_TEST_USER if ICHAIN_MODE == 'simulate' and ICHAIN_TEST_USER
    if ichain_user
      session[:login] = ichain_user
      session[:email] = request.env['HTTP_X_EMAIL']
      # Set the headers for direct connection to the api, TODO: is this thread safe?
      transport = ActiveXML::Config.transport_for( :project )
      transport.set_additional_header( "X-Username", ichain_user )
      transport.set_additional_header( "X-Email", session[:email] ) if session[:email]
    end
  end

  
  def authenticate_basic_auth
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
      if authorization and authorization.size == 2 and authorization[0] == "Basic"
        login, passwd = Base64.decode64( authorization[1] ).split(/:/)
        if login and passwd
          logger.debug "Using authorization: #{authorization} to login user #{login}"
          session[:login] = login
          session[:passwd] = passwd
        end
      end
      if session[:login] and session[:passwd]
      # pass credentials to transport plugin, TODO: is this thread safe?
      ActiveXML::Config.transport_for(:project).login session[:login], session[:passwd]
    end
  end

  def authenticate_form_auth
    if params[:username] and params[:password]
      session[:login] = params[:username]
      session[:passwd] = params[:password]
      logger.debug "Using form authorization to login user #{session[:login]}"
    end
    if session[:login] and session[:passwd]
      # pass credentials to transport plugin, TODO: is this thread safe?
      ActiveXML::Config.transport_for(:project).login session[:login], session[:passwd]
    end
  end

  def frontend
    FrontendCompat.new
  end

  def valid_project_name? name
    name =~ /^\w[-_+\w\.:]+$/
  end

  def valid_package_name? name
    name =~ /^\w[-_+\w\.:]*$/
  end

  def valid_role_name? name
    name =~ /^\w+$/
  end

  def valid_platform_name? name
    name =~ /^\w[-_\w]*$/
  end

  def reset_activexml
    transport = ActiveXML::Config.transport_for(:project)
    transport.delete_additional_header "X-Username"
    transport.delete_additional_header "X-Email"
    transport.delete_additional_header 'Authorization'
  end


  def rescue_action_locally( exception )
    rescue_action_in_public( exception )
  end


  def rescue_action_in_public( exception )
    logger.error "rescue_action: caught #{exception.class}: #{exception.message}"
    begin
      api_error = REXML::Document.new( exception.message ).root
    rescue Object => e
      logger.error "Couldn't parse error xml: #{e.message}"
    end

    if api_error and api_error.name == "status"
      code = api_error.attributes['code']
      message = api_error.elements['summary'].text
      api_exception = api_error.elements['exception'] if api_error.elements['exception']
    else
      code = "unknown"
      message = exception.message
    end

    case exception
    when ActionController::RoutingError
      render_error :code => code, :message => message, :status => 404
    when ActiveXML::Transport::ForbiddenError
      ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if !local_request?
      render_error :code => code, :message => message, :status => 401
    when ActiveXML::Transport::ConnectionError
      ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if !local_request?
      render_error :message => "Unable to connect to API host. (#{FRONTEND_HOST})", :status => 200
    when Timeout::Error
       render_error :status => 400, :code => code, :message => message,
        :exception => exception, :api_exception => api_exception
    else
      if code != 404 && !local_request?
        ExceptionNotifier.deliver_exception_notification(exception, self, request, {})
      end
      render_error :status => 400, :code => code, :message => message,
        :exception => exception, :api_exception => api_exception
    end
  end
  

  def render_error( opt={} )
    @code = opt[:code] || 500
    @message = opt[:message] || "No message set"
    @exception_xml = opt[:exception_xml] if local_request?
    @exception = opt[:exception] if local_request?
    @status = opt[:status] || 400
    logger.debug "ERROR: #{@code} #{@message}"
    if request.xhr?
      render :text => @message, :status => @status, :layout => false
    else
      render :template => 'error', :status => @status
    end
  end

  def valid_http_methods(*methods)
    methods.map {|x| x.to_s.downcase.to_s}
    unless methods.include? request.method
      raise InvalidHttpMethodError, "Invalid HTTP Method: #{request.method.to_s.upcase}"
    end
  end


end
