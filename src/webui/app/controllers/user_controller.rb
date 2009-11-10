class UserController < ApplicationController

  skip_before_filter :require_login, :only => [:login]

  def logout
    logger.info "Logging out: #{session[:login]}"
    reset_session
    @return_to_path = "/"
    if ICHAIN_MODE != 'off'
      redirect_to '/cmd/ICSLogout'
    end
  end

  def login
    @return_to_path = params['return_to_path'] || "/"
  end
  
  def do_login
    @return_to_path = params['return_to_path'] || "/"
    if params[:username] and params[:password]
      logger.debug "Doing form authorization to login user #{params[:username]}"
      session[:login] = params[:username]
      session[:passwd] = params[:password]
      authenticate_form_auth
      begin
        Person.find( session[:login] )
      rescue ActiveXML::Transport::UnauthorizedError => exception
        logger.info "Login to #{@return_to_path} failed for #{session[:login]}: #{exception}"
        reset_session
        flash.now[:error] = "Authentication failed"
        render :template => "user/login", :locals => {:return_to_path => @return_to_path} and return
      end
      flash[:success] = "You are logged in now"
      redirect_to params[:return_to_path]
    end
  end


  def edit
    @user ||= Person.find :login => session[:login]
  end


  def save
    @user ||= Person.find :login => session[:login]
    @user.realname.data.text = params[:realname]
    if @user.save
      flash[:note] = "User data for user '#{@user.login}' successfully updated."
    else
      flash[:note] = "Failed to save user data for user '#{user.login}'."
    end
    session[:user] = nil
    redirect_to :controller => "home"
  end


  def register
    valid_http_methods(:post)
    logger.debug "Creating new person #{session[:login]}"
    unreg_person_opts = {
      :login => session[:login],
      :email => session[:email],
      :realname => "",
      :explanation => ""
    }
    person = Unregisteredperson.new(unreg_person_opts)
    person.save
    flash[:success] = "Your buildservice account is now active."
    redirect_to :controller => :project, :project => "home:#{session[:login]}"
  end

end
