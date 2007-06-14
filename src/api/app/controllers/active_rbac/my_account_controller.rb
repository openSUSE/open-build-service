# This controller provides a frontend for users to edit their data.
# Currently, only "change password" has been implemented.

class ActiveRbac::MyAccountController < ActiveRbac::ComponentController

  # Allows the user to change his password. If the user is in the 
  # "retrieved_password" state then the view will display a notice
  # about the fact that the user *has* to change his password to
  # be able to proceed.
  def change_password
    # the user must be logged in - d'oh
    if session[:rbac_user_id].nil?
      flash[:error] = "You are not logged in."
      redirect_to '/'
      return
    end

    @user = User.find(session[:rbac_user_id])
    
    # only render the form on GET
    return if request.get?
    
    # process the input data on POST
    
    # check that the entered password equals the user's current one
    if not @user.password_equals?(params[:current_password])
      @user.errors.add_to_base('The value of current password does not match your current password.')
      return
    end
    
    # Set password and password confirmation into the user object and try
    # to save. Render form again on errors.
    @user.password = params[:password]
    @user.password_confirmation = params[:password_confirmation]
    @user.state = User.states['confirmed']
    @user.save!
    
    # Everything went well. Redirect to '/' and set a nice flash message
    flash[:success] = 'You have changed your password successfully.'
  end
  
end