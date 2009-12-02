# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'common/activexml/transport'

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
    logger.debug "Setting return_to: \"#{@return_to_path}\""
  end

  def set_charset
    if !request.xhr? && !headers.has_key?('Content-Type')
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
    ichain_user = request.env['HTTP_X_USERNAME']
    ichain_user = ICHAIN_TEST_USER if ICHAIN_MODE == 'simulate' and ICHAIN_TEST_USER
    ichain_email = request.env['HTTP_X_EMAIL']
    ichain_email = ICHAIN_TEST_EMAIL if ICHAIN_MODE == 'simulate' and ICHAIN_TEST_EMAIL
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
    name =~ /^\w[-_+\w\.:]+$/
  end

  def valid_package_name? name
    name =~ /^\w[-_+\w\.]*$/
  end

  def valid_role_name? name
    name =~ /^\w+$/
  end

  def valid_platform_name? name
    name =~ /^\w[-_\.\w]*$/
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
    message, code, api_exception = ActiveXML::Transport.extract_error_message exception

    case exception
    when ActionController::RoutingError
      render_error :code => code, :message => message, :status => 404
    when ActiveXML::Transport::ForbiddenError
      # switch to registration on first access
      if code == "unregistered_ichain_user"
        render :template => "user/request_ichain" and return
      else
        ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if send_exception_mail?
        render_error :code => code, :message => message, :status => 401
      end
    when ActiveXML::Transport::UnauthorizedError
      ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if send_exception_mail?
      render_error :code => code, :message => 'Unauthorized access', :status => 401
    when ActionController::InvalidAuthenticityToken
      render_error :code => code, :message => 'Invalid authenticity token', :status => 401
    when ActiveXML::Transport::ConnectionError
      ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if send_exception_mail?
      render_error :message => "Unable to connect to API host. (#{FRONTEND_HOST})", :status => 200
    when Timeout::Error
      ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if send_exception_mail?
      render_error :status => 400, :code => code, :message => message,
        :exception => exception, :api_exception => api_exception
    when Net::HTTPBadResponse
      # The api sometimes sends responses without a proper "Status:..." line (when it restarts?)
      render_error :message => "Unable to connect to API host. (#{FRONTEND_HOST})", :status => 200
    else
      if code != 404 && send_exception_mail?
        ExceptionNotifier.deliver_exception_notification(exception, self, request, {})
      end
      render_error :status => 400, :code => code, :message => message,
        :exception => exception, :api_exception => api_exception
    end
  end

  def render_error( opt={} )
    @code = opt[:code] || 500
    @message = opt[:message] || "No message set"
    @exception = opt[:exception] if local_request?
    @api_exception = opt[:api_exception] if local_request?
    @status = opt[:status] || 400
    logger.debug "ERROR: #{@code}; #{@message}"
    if request.xhr?
      render :text => @message, :status => @status, :layout => false
    else
      render :template => 'error', :locals => {:code => @code, :message => @message,
        :exception => @exception, :status => @status, :api_exception => @api_exception }
    end
  end

  def valid_http_methods(*methods)
    methods.map {|x| x.to_s.downcase.to_s}
    unless methods.include? request.method
      raise InvalidHttpMethodError, "Invalid HTTP Method: #{request.method.to_s.upcase}"
    end
  end

  def send_exception_mail?
    return !local_request? && ENV['RAILS_ENV'] != 'development'
  end

end
