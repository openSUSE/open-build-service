# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

#hack to autoload activexml and frontendcontroller on change
require_dependency 'activexml'
require_dependency 'opensuse/frontend'


class ApplicationController < ActionController::Base
  session_options[:prefix] = "ruby_webclient_sess."
  session_options[:key] = "opensuse_webclient_session"

  before_filter :authorize 
  
  #filter
  def authorize
    session[:return_to] = request.request_uri
    if ichain_host
      logger.debug "Have an iChain host: #{ichain_host}"
      ichain_user = request.env['HTTP_X_USERNAME']
# TEST vv
      unless ichain_user
        ichain_user = "freitag"
        logger.debug "TEST-ICHAIN_USER freitag set!"
        request.env.each do |name, val|
          logger.debug "Header value: #{name} = #{val}"
        end
# TEST ^^
      else
        logger.debug "iChain-User from environment: #{ichain_user}"
      end

      if ichain_user
        # Do the transport
        TRANSPORT.login proc {
          # STDERR.puts session.inspect
          [ ichain_user ]
        }
      else 
        redirect_to :controller => 'user', :action => 'ichain_login'
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
      
      if authorization and authorization[0] == "Basic"
        logger.debug( "AUTH2: #{authorization}" )
      
        login, passwd = Base64.decode64( authorization ).split(/:/)
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
    end

    # Do the transport
    TRANSPORT.login proc {
      # STDERR.puts session.inspect
      [ session[:login], session[:passwd] ]
    }

  end

  def rescue_action_in_public( exception )
    logger.debug "rescue_action_in_public: caught #{exception.class}: #{exception.message}"
    if exception.message.kind_of? REXML::Document 
      if exception.message.root.elements['code']
        @code = exception.message.root.elements['code'].text
      else
        @code = exception.message.root.attributes['code']
      end
      @message = exception.message.root.elements['summary'].text
      if exception.message.root.elements['exception']
        @api_exception = exception.message.root.elements['exception']
      end
    else
      @code = 500
      @message = exception.message
      @exception = exception
    end

    case exception
    when Suse::Frontend::UnauthorizedError
      session[:login] = nil
      session[:passwd] = nil
      
      flash[:error] = exception.message.root.elements['summary'].text
      
      redirect_to :controller => 'user', :action => 'login'
#   when Suse::Frontend::ForbiddenError
#     render_error :code => @code, :message => @message
#   when Suse::Frontend::ConnectionError
#     render_error :code => @code, :message => @message
#   when ActiveXML::GeneralError
#     render_error :code => @code, :message => @message
    else
      logger.debug "default exception handling"
      render_error :code => @code, :message => @message, :exception => @exception, :api_exception => @api_exception
    end
  end

  def render_error( opt={} )
    @code = opt[:code] || 500
    @error_message = opt[:message] || "No message set"
    @exception_xml = opt[:exception_xml]
    @exception = opt[:exception]


    # if the exception was raised inside a template (-> @template.first_render != nil), 
    # the instance variables created in here will not be injected into the template
    # object, so we have to do it manually
    if @template.first_render
      logger.debug "injecting error instance variables into template object"
      %w{@error_message @code @exception_xml @exception}.each do |var|
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
      @frontend = TRANSPORT
    end
    @frontend
  end

  def ichain_host
    # if const_defined? "ICHAIN_HOST"
      ICHAIN_HOST
    # end
    # nil
  end
end
