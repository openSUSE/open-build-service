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

  def edit
    @user = Person.find :login => session[:login] if !@user
  end


  def save
    @user = Person.find :login => session[:login] if !@user
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
    redirect_to :controller => "home"
  end

end
