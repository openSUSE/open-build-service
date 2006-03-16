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
    
    logger.debug "application/authorize: login: #{session[:login]}, passwd: XXXX"

    unless session[:login]
      authorization = request.env[ "HTTP_AUTHORIZATION" ]

      if authorization and authorization =~ /^\s*Basic /
        authorization.sub!( /^\s*Basic /, '' )
        # logger.debug( "AUTH2: #{authorization}" )
      
        userpass = Base64.decode64( authorization ).split(/:/)
        if userpass
          session[:login] = userpass[0]
	  session[:passwd] = userpass[1]
        end
      else
        session[:return_to] = request.request_uri
        redirect_to :controller => 'user', :action => 'login'
      end
    end
    
    # Do the transport
    TRANSPORT.login proc {
      # STDERR.puts session.inspect
      [session[:login], session[:passwd]]
    }

  end

  def rescue_action_in_public( exception )
    logger.debug "rescue_action_in_public: caught #{exception.class}: #{exception.message}"
    if exception.message.kind_of? REXML::Document 
      @code = exception.message.root.elements['code'].text
      @message = exception.message.root.elements['summary'].text
    else
      @code = 500
      @message = exception.message
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
      render_error :code => @code, :message => @message
    end
  end

  def render_error( opt={} )
    @code = opt[:code] || 500
    @error_message = opt[:message] || "No message set"


    # if the exception was raised inside a template (-> @template.first_render != nil), 
    # the instance variables created in here will not be injected into the template
    # object, so we have to do it manually
    if @template.first_render
      logger.debug "injecting error instance variables into template object"
      %w{@error_message @code}.each do |var|
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

end
