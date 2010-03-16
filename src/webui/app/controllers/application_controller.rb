# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'common/activexml/transport'

class ApplicationController < ActionController::Base

  before_filter :instantiate_controller_and_action_names
  before_filter :set_return_to, :reset_activexml, :authenticate
  after_filter :set_charset
  protect_from_forgery

  # Scrub sensitive parameters from your log
  filter_parameter_logging :password

  class InvalidHttpMethodError < Exception; end
  class MissingParameterError < Exception; end
  
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
      render :text => 'Please login' and return if request.xhr?
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

  def valid_file_name? name
    name =~ /^[-\w_+~ ][-\w_\.+~ ]*$/
  end

  def valid_role_name? name
    name =~ /^[\w\-_\.+]+$/
  end

  def valid_platform_name? name
    name =~ /^\w[-_\.\w&]*$/
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
      render_error :code => 404, :message => "no such route"
    when ActionController::UnknownAction
      render_error :code => 404, :message => "unknown action"
    when ActiveXML::Transport::ForbiddenError
      # switch to registration on first access
      if code == "unregistered_ichain_user"
        render :template => "user/request_ichain" and return
      else
        ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if send_exception_mail?
        render_error :code => 401, :message => message
      end
    when ActiveXML::Transport::UnauthorizedError
      ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if send_exception_mail?
      render_error :code => 401, :message => 'Unauthorized access'
    when ActionController::InvalidAuthenticityToken
      render_error :code => 401, :message => 'Invalid authenticity token'
    when ActiveXML::Transport::ConnectionError
      ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if send_exception_mail?
      render_error :message => "Unable to connect to API host. (#{FRONTEND_HOST})", :status => 503
    when Timeout::Error
      ExceptionNotifier.deliver_exception_notification(exception, self, request, {}) if send_exception_mail?
      render_error :code => 504, :message => message,
        :exception => exception, :api_exception => api_exception
    when Net::HTTPBadResponse
      # The api sometimes sends responses without a proper "Status:..." line (when it restarts?)
      render_error :message => "Unable to connect to API host. (#{FRONTEND_HOST})", :status => 503
    else
      if code != 404 && send_exception_mail?
        ExceptionNotifier.deliver_exception_notification(exception, self, request, {})
      end
      render_error :status => 400, :code => code, :message => message,
        :exception => exception, :api_exception => api_exception
    end
  end

  def render_error( opt={} )
    @status = opt[:status] || opt[:code] || 400
    @code = opt[:code] || 500
    begin
      @code = Integer(@code)
    rescue ArgumentError
    end
    begin
      @status = Integer(@status)
    rescue ArgumentError
    end
    @message = opt[:message] || "No message set"
    @exception = opt[:exception] if local_request?
    @api_exception = opt[:api_exception] if local_request?
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

  def required_parameters(params, parameters)
    parameters.each do |parameter|
      unless params.include? parameter.to_s
        raise MissingParameterError, "Required Parameter #{parameter} missing"
      end
    end
  end

  def send_exception_mail?
    return !local_request? && !Rails.env.development? && ExceptionNotifier.exception_recipients && ExceptionNotifier.exception_recipients.length > 0
  end

  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
  end

end
