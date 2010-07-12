class UserController < ApplicationController

  before_filter :require_login, :only => [:edit, :save, :register]
  before_filter :check_user, :only => [:edit, :save]

  def logout
    logger.info "Logging out: #{session[:login]}"
    reset_session
    @user = nil
    @return_to_path = "/"
    if ICHAIN_MODE == 'on'
      redirect_to '/cmd/ICSLogout'
    end
    Person.free_cache session
  end

  def login
    @return_to_path = params['return_to_path'] || "/"
  end
  
  def edit
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

  def save
    @user.realname.text = params[:realname]
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
    begin
      find_cached(Person, session[:login] )
      logger.info "User #{session[:login]} already exists..."
      redirect_to :controller => :project, :action => :show, :project => "home:#{session[:login]}"
      return
    rescue
    end
    logger.debug "Creating new person #{session[:login]}"
    unreg_person_opts = {
      :login => session[:login],
      :email => session[:email] || 'nomail@nomail.com',
      :realname => "",
      :explanation => ""
    }
    person = Unregisteredperson.new(unreg_person_opts)
    person.save
    flash[:success] = "Your buildservice account is now active."
    redirect_to :controller => :project, :action => :show, :project => "home:#{session[:login]}"
  end

end
