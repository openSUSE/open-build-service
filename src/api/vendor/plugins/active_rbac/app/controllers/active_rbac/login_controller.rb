# This controller provides actions to log a user in and out.

class ActiveRbac::LoginController < ActiveRbac::ComponentController
  # Use the configured layout.
  layout ActiveRbacConfig.config(:controller_layout)

  # The user cannot access the logout pages when he is logged in.
  verify :session     => :rbac_user, 
         :redirect_to => '/',
         :only        => [ :logout ],
         :add_flash   => { :notice => 'You can only log out when you have logged in.' }

  # Redirects to #login
  def index
    redirect_to :action => 'login'
  end

  # Displays the login form on GET and performs the login on POST. Expects the
  # Expects the "login" and "password" parameters to be set. Displays the #login
  # form on errors. The user must not be logged in.
  def login
    # Check that the use is not already logged in
    unless session[:rbac_user].nil?
      render :template => 'active_rbac/login/already_logged_in'
      return
    end
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
    write_user_to_session(user)

    render :template => 'active_rbac/login/login_success'
  rescue ActiveRecord::RecordNotFound
    # Add an error and let the action render normally.
    @errors << 'Invalid user name or password!'
  end

  # Displays the logout confirmation form on GET and performs the logout on 
  # POST. Expects the "yes" parameter to be set. If this is the case, the 
  # user's authentication state is clear. If it is not the case, the use will
  # be redirected to '/'. User must be logged in
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
    self.remove_user_from_session!

    # Render success template.
    render :template => 'active_rbac/login/logout_success'
  end

  protected
    # Store the given user into :rbac_user sesion_variable
    def write_user_to_session(user)
      session[:rbac_user] = user
    end
  
    # Remove the given user from teh :rbac_user session variable.
    def remove_user_from_session!
      session[:rbac_user] = nil
    end
end