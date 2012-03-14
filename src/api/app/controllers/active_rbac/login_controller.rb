# This controller provides actions to log a user in and out.

class ActiveRbac::LoginController < ActiveRbac::ComponentController
  # Use the configured layout.
  layout "rbac.rhtml"

  # The user cannot access the logout pages when he is logged in.
  #verify :session     => :rbac_user_id, 
  #       :redirect_to => '/',
  #       :only        => [ :logout ],
  #       :add_flash   => { :notice => 'You can only log out when you have logged in.' }

  # Redirects to #login
  def index
    redirect_to :action => 'login'
  end

  # Displays the login form on GET and performs the login on POST. Expects the
  # Expects the "login" and "password" parameters to be set. Displays the #login
  # form on errors. The user must not be logged in.
  #
  # Checks the session entry <tt>return_to</tt> and the parameter 
  # <tt>return_to</tt> for information of where to redirect to after the login
  # has been performed successfully (in this order).
  #
  # Will write the value into the <tt>return_to</tt> session parameter if it
  # came from parameter and clear it after the login has been performed 
  # successfully.
  #
  # If the login is successful then the current session will be reset using
  # reset_session and all session values will be copied into a new one.
  def login
    # Check that the use is not already logged in
    unless session[:rbac_user_id].nil?
      redirect_with_notice_or_render :warning, 'You are already logged in.',
        'active_rbac/login/already_logged_in'
      return
    end

    # Set the location to redirect to in the session if it was passed in through
    # a parameter and none is stored in the session.
    if session[:return_to].nil? and !params[:return_to].nil?
      session[:return_to] = params[:return_to] 
    end
    # Store the :return_to session value in an object variable so it is accessible
    # after storing the user id in the session (which will clear the session).
    @return_to = session[:return_to]
    
    # Simply render the login form on everything but POST.
    return unless request.method == :post

    # Handle the login request otherwise.
    @errors = Array.new

    # If login or password is missing, we can stop processing right away.
    raise ActiveRecord::RecordNotFound if params[:login].to_s.empty? or params[:password].to_s.empty?

    # Try to log the user in.
    user = User.find_with_credentials(params[:login], params[:password])

    # Check whether a user with these credentials could be found.
    raise ActiveRecord::RecordNotFound unless not user.nil?

    # Check that the user has the correct state
    raise ActiveRecord::RecordNotFound unless User.state_allows_login?(user.state)

    # Write the user into the session object.
    create_new_session(user)

    redirect_with_notice_or_render :success, 'You have logged in successfully.',
      'active_rbac/login/login_success'
  rescue ActiveRecord::RecordNotFound
    # Add an error and let the action render normally.
    @errors << 'Invalid user name or password!'
  end

  # Displays the logout confirmation form on GET and performs the logout on 
  # POST. Expects the "yes" parameter to be set. If this is the case, the 
  # user's authentication state is clear. If it is not the case, the use will
  # be redirected to '/'. User must be logged in
  #
  # The whole session will be reset on the user's logout using "reset_session".
  def logout
    # Note: The check for the user to be logged in is in a verify above.
    # Simply render the login form on everything but POST.
    return unless request.method == :post

    # Do not log out if the user did not press the "Yes" button
    if params[:yes].nil?
      redirect_to '/'
      return
    end

    # Otherwise delete the user from the session
    remove_user_from_session!

    # Render success template.
    render :template => 'active_rbac/login/logout_success'
  end

  protected
    # Clear the session (so a new one is created) and store the given user 
    # into :rbac_user_id sessíon_variable.
    def create_new_session(user)
      @active_rbac_user = nil
      reset_session
      session[:rbac_user_id] = user.id
    end
  
    # Clear the current session to remove the given user id from the 
    # :rbac_user_id session variable. This will create a new session.
    def remove_user_from_session!
      @active_rbac_user = nil
      reset_session
    end

    # Redirects to the location stored in the <tt>@return_to</tt> property
    # and clears it if it is set or renders the template at the given path.
    # Sets <tt>flash[level]</tt> to the first parameter if it redirects.
    def redirect_with_notice_or_render(level, notice, template)
      if @return_to.nil?
        render :template => template
      else
        flash[level] = notice
        redirect_to @return_to
      end
    end
end
