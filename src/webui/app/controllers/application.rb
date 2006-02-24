# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

#hack to autoload activexml and frontendcontroller on change
require_dependency 'activexml'
require_dependency 'opensuse/frontend'


class ApplicationController < ActionController::Base
  session_options[:prefix] = "ruby_webclient_sess."
  session_options[:key] = "opensuse_webclient_session"

  prepend_before_filter :authorize, :except => [ :index ]
  before_filter :transmit_credentials, :except => [ :index ]
  
  def transmit_credentials
    # We need to call authorize here because the transmit_credentials method seems
    # to get called very early in the chain from the lib probably...
    authorize false
    
    TRANSPORT.login proc {
      # STDERR.puts session.inspect
      [session[:login], session[:passwd]]
    }
  end

  #filter
  def authorize( do_redirect = true )
    
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
        if do_redirect
          session[:return_to] = request.request_uri
          redirect_to :controller => 'user', :action => 'login'
	end
      end
    end
  end

  def rescue_action_in_public( exception )
    logger.debug "rescue_action_in_public: caught #{exception.inspect}"
    case exception
    when Suse::Frontend::UnauthorizedError
      session[:login] = nil
      session[:passwd] = nil

      flash[:error] = exception.message.root.elements['summary'].text
      
      redirect_to :controller => 'user', :action => 'login'
    when Suse::Frontend::ForbiddenError
      # if ENV[ "RAILS_ENV"] == "development"
      #  raise exception
      # else
        @excep = exception.message.root
	@code = @excep.elements['code'].text
        render :template => 'error'
      # end
    when Suse::Frontend::ConnectionError
      @code = exception.message.root.elements['code'].text
      @error_message = exception.message.root.elements['summary'].text
      render :template => 'error', :status => @code
    when ActiveXML::GeneralError
      @code = exception.message.root.elements['code'].text
      render :template => 'error', :status => 442
    else
      raise exception
    end
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
