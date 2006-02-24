# This controller provides actions for users to register with the system
# and retrieve lost passwords
class ActiveRbac::RegistrationController < ActiveRbac::ComponentController
  uses_component_template_root

  # The layout this controller uses is configured in the 
  # Configuration class
  layout config.controller[:layout]

  # Redirect to signup page
  def index
    redirect_to :action => 'register'
  end

  # Displays a "registration" form on GET and tries to register a user on POST.
  def register
    if request.method != :post
      # On anything but POST, we simply initialize @user with a new User object
      # for the form.
      @user = User.new
    else 
      # On POST we try to register the user.
      
      # Set password and password_confirmation into [:user] parameters
      params[:user] = Hash.new if params[:user].nil?
      params[:user][:password] = params[:password]
      params[:user][:password_confirmation] = params[:password_confirmation]

      # Execute the blocks given for the signup_fields configuration settings.
      # These will add validation functions to the User model.
      config.controller[:registration][:signup_fields].each { |field| field[:validation_proc].call }

      @user = User.new(params[:user])
      @user.password_hash_type = config.model[:default_hash_type]

      if @user.save then
        @user.create_user_registration

        # The confirm_url should be set in the mailer, but seemingly the url methods
        # hooked up with the routing are not available there.
        confirm_url = url_for(:controller => 'registration', 
                              :action => 'confirm', 
                              :user => @user.id, 
                              :token => @user.user_registration.token)
        RegistrationMailer.deliver_confirm_registration(@user, confirm_url)

        render 'active_rbac/registration/register_success'
        return
      end
    end

    # Set the additional partials to render within the form into the template
    @additional_partials = config.controller[:registration][:signup_fields].collect { |field| field[:template_path] }
  end
  
  # Displays a "do you really want to confirm registration" form on GET and
  # tries to confirm the user's registration on POST.
  def confirm
    if request.method != :post
      # Show the confirmation form on anything but GET
      @user = User.find(params[:user])

      unless !@user.user_registration.nil? and @user.user_registration.token == params[:token]
        # moo, just to get into the right rescue below
        raise ActiveRecord::RecordNotFound 
      end
    
      @token = params[:token]
    else
      # Handle the confirmation on POST.
      if params[:yes].nil?
        # User said "no"
        flash[:notice] = 'Your registration has not been confirmed.'
        redirect_to '/'
      end

      @user = User.find(params[:user])

      unless !@user.user_registration.nil? and @user.user_registration.token == params[:token]
        # moo, just to get into the right rescue below
        raise ActiveRecord::RecordNotFound 
      end

      # Delete UserRegistration for good
      @user.state = User.states['confirmed']
      @user.save
      UserRegistration.delete @user.user_registration.id

      render 'active_rbac/registration/confirm_success'
    end
  rescue ActiveRecord::RecordNotFound
    render 'active_rbac/registration/confirm_failure'
  end
  
  # Displays "lost password form" on GET and tries to send a new one on POST.
  def lostpassword
    @errors = Array.new

    if request.method == :post
      # Try to find the user with the given login and email adress
      @user = User.find :first,
                        :conditions => [ 'login = ? AND email = ?', params[:login], params[:email]]


      # We raise this here manually to have error handling in one place only
      raise ActiveRecord::RecordNotFound if @user.nil?

      # A bit abusive to raise this exception here, but it is the same
      # error that is visible to users.
      raise ActiveRecord::RecordNotFound unless @user.state == User.states['confirmed']

      # Change the user's password to a random one
      password = Digest::MD5.hexdigest((rand 1000).to_s + Time.now.to_s).slice(1,10)
      @user.update_password password
      @user.save

      # Deliver lost password email
      RegistrationMailer.deliver_lost_password(@user, password)

      # Render a success page
      render 'active_rbac/registration/lostpassword_success'
    end
  rescue ActiveRecord::RecordNotFound
    @errors << 'You have entered an invalid user name or an invalid email address.'
  end
end