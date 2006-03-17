require File.dirname(__FILE__) + '/../test_helper'
require 'registration_controller'

# Re-raise errors caught by the controller.
class ActiveRbac::RegistrationController; def rescue_action(e) raise e end; end

class ActiveRbac::RegistrationControllerTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles, :static_permissions, :roles_static_permissions

  def setup
    @controller = ActiveRbac::RegistrationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    @valid_registration_data = {
      :password => 'MyPasswordIsNice',
      :password_confirmation => 'MyPasswordIsNice',
      :user => {
        :login => 'Test Login',
        :email => 'test@localhost'
      }
    }
    @valid_confirmation_data = {}  # This is set in send_registration request if successful
    @valid_lost_password_data = {
      :login => 'Test Login',
      :email => 'test@localhost'
    }
    
    @emails = ActionMailer::Base.deliveries 
    @emails.clear 
  end

  #
  # Request sending methods.
  #

  # This method simulates a registration request to the controller. It also
  # sets the corresponding @valid_confirmation_data for the just created user.
  def send_registration_request(data)
    post 'register', :user => data[:user], :password => data[:password], :password_confirmation => data[:password_confirmation]
    unless data[:user][:login].nil?
      user = User.find_by_login(data[:user][:login])
      unless user.nil? or user.user_registration.nil?
        @valid_confirmation_data = { :user => user.id, :token => user.user_registration.token }
      end
    end
  rescue ActiveRecord::RecordNotFound
    # Rescue only here when trying to build the @valid_confirmation_data
    data[:user][:login] = "<<NOT SET>>" if data[:user][:login].nil?
  end

  # This method simulates a registration request for a registration appliance
  # to the server.
  def send_confirm_get_request(data)
    get 'confirm', :user => data[:user], :token => data[:token]
  end

  # This method sends a valid "lost password" request to the server
  def send_lost_password_request(data)
    post 'lostpassword', :login => data[:login], :email => data[:email]
  end
  
  # This method sends a valid "confirm" request via POST to the server.
  def send_confirm_post_requests(data, yes=true)
    if yes
      post 'confirm', :user => data[:user], :token => data[:token], :yes => 'Yes'
    else
      post 'confirm', :user => data[:user], :token => data[:token], :no => 'No'
    end
  end
  
  #
  # Actual tests
  #
  
  def test_should_display_registration_form_on_get_register
    get 'register'
    
    assert_response :success
    assert_template 'register'
  end

  def test_should_add_correct_user_record_on_valid_post_to_register
    send_registration_request @valid_registration_data
    
    assert_response :success
    assert_template 'register_success'
    
    user = nil
    assert_nothing_raised { user = User.find_by_login @valid_registration_data[:user][:login] }
    assert_not_nil user
    assert_equal @valid_registration_data[:user][:login], user.login
    assert_equal @valid_registration_data[:user][:email], user.email
  end
  
  def test_should_add_correct_registration_record_on_valid_post_to_register
    send_registration_request @valid_registration_data

    user = User.find_by_login @valid_registration_data[:user][:login]

    assert_not_nil user.user_registration
    assert_in_delta user.user_registration.created_at, Time.now, 10
    assert_in_delta user.user_registration.expires_at, user.user_registration.created_at + (60*60*24), 2
  end
  
  def test_should_send_registration_email_on_valid_post_to_register
    send_registration_request @valid_registration_data

    user = User.find_by_login @valid_registration_data[:user][:login]
    
    assert_equal 1, @emails.length
    email = @emails.first
    assert_equal ActiveRbacConfig.config(:mailer_subject_confirm_registration), email.subject
    assert_equal [ 'activerbac@localhost' ].sort {|a,b| a.id <=> b.id}, email.from.sort {|a,b| a.id <=> b.id}
    assert_equal = user.email, email.to.first
    re = Regexp.new "registration/confirm/#{user.id}/#{user.user_registration.token}"
    assert_match re, email.body
    re = Regexp.new "#{user.login}"
    assert_match re, email.body
  end
  
  def test_should_succeed_on_valid_confirm_post_request
    send_registration_request @valid_registration_data
    send_confirm_get_request @valid_confirmation_data
    send_confirm_post_requests @valid_confirmation_data
    
    assert_response :success
    assert_template 'confirm_success'

    @user = User.find @valid_confirmation_data[:user]
    assert @user.user_registration.nil?
  end

  def test_should_succeed_on_valid_confirm_post_request
    send_registration_request @valid_registration_data
    send_confirm_get_request @valid_confirmation_data
    send_confirm_post_requests @valid_confirmation_data, true
    
    assert_response :success
    assert_template 'confirm_success'
    
    @user = User.find @valid_confirmation_data[:user]
    assert @user.user_registration.nil?
  end

  def test_should_remove_user_registration_record_on_valid_confirm_post_request
    send_registration_request @valid_registration_data
    send_confirm_get_request @valid_confirmation_data
    send_confirm_post_requests @valid_confirmation_data

    user = User.find_by_login @valid_registration_data[:user][:login]
    assert_nil user.user_registration
  end

  def test_should_change_state_on_valid_confirm_post_request
    send_registration_request @valid_registration_data
    send_confirm_get_request @valid_confirmation_data
    send_confirm_post_requests @valid_confirmation_data
    
    user = User.find_by_login @valid_registration_data[:user][:login]
    
    assert_equal User.states['confirmed'], user.state
  end
  
  def test_should_display_form_on_lost_password_request
    get 'lostpassword'
    
    assert_response :success
    assert_template 'lostpassword'
  end
  
  def test_should_succeed_on_valid_new_password_request
    send_registration_request @valid_registration_data
    send_confirm_get_request @valid_confirmation_data
    send_confirm_post_requests @valid_confirmation_data
    send_lost_password_request @valid_lost_password_data

    user = User.find_by_login @valid_registration_data[:user][:login]
    
    assert_response :success
    assert_template 'lostpassword_success'
    assert_tag :tag => 'p', :content => Regexp.new("#{user.login}")
  end
  
  def test_should_change_password_on_valid_new_password_request
    send_registration_request @valid_registration_data

    assert_response :success
    assert_template 'register_success'

    user = User.find_by_login @valid_registration_data[:user][:login]
    password = user.password

    send_confirm_post_requests @valid_confirmation_data
    
    assert_response :success
    assert_template 'confirm_success'
    
    send_lost_password_request @valid_lost_password_data
    
    assert_response :success
    assert_template 'lostpassword_success'

    user.reload
    assert_not_equal password, user.password
  end

  def test_should_change_user_state_on_valid_new_password_request
    send_registration_request @valid_registration_data

    user = User.find_by_login @valid_registration_data[:user][:login]
    state = user.state, 'This is a known error: https://activerbac.turingstudio.com/trac/ticket/50'

    send_confirm_get_request @valid_confirmation_data
    send_lost_password_request @valid_lost_password_data

    user.reload
    assert_not_equal state, user.state
  end

  def test_should_send_changed_password_email_on_valid_new_password_request
    send_registration_request @valid_registration_data
    send_confirm_get_request @valid_confirmation_data
    send_confirm_post_requests @valid_confirmation_data

    @emails.clear # clear out the confirmation email
    
    send_lost_password_request @valid_lost_password_data
    assert_response :success
    assert_template 'lostpassword_success'
    
    user = User.find_by_login @valid_registration_data[:user][:login]

    assert_equal 1, @emails.length
    email = @emails.first
    assert_equal ActiveRbacConfig.config(:mailer_subject_lost_password), email.subject
    assert_equal [ 'activerbac@localhost' ].sort {|a,b| a.id <=> b.id}, email.from.sort {|a,b| a.id <=> b.id}
    assert_match Regexp.new("#{user.login}"), email.body
    # TODO: Add login URL here.
  end
  
  def test_should_fail_on_empty_registration_request
    post 'register'
    
    assert_response :success
    assert_template 'register'

    assert_tag :tag => 'li', :content => "Password must be given"
    assert_tag :tag => 'li', :content => "User name must be given"
    assert_tag :tag => 'li', :content => "Email must be a valid email address"
    assert_tag :tag => 'li', :content => "Email must be given"
  end
  
  def test_should_fail_on_invalid_registration_request_with_invalid_chars_in_login
    invalid_registration_data = @valid_registration_data
    invalid_registration_data[:user][:login] = 'I used evil chars#~.+*'
    send_registration_request invalid_registration_data
    
    assert_response :success
    assert_template 'register'
    assert_tag :tag => 'li', :content => 'User name must not contain invalid characters.'
  end
  
  def test_should_fail_on_invalid_registration_request_with_too_long_login
    invalid_registration_data = @valid_registration_data
    invalid_registration_data[:user][:login] = 'e' * 101
    send_registration_request invalid_registration_data

    assert_response :success
    assert_template 'register'
    assert_tag :tag => 'li', :content => 'User name must have less than 100 characters.'
  end
  
  def test_should_fail_on_invalid_registration_request_with_too_short_login
    invalid_registration_data = @valid_registration_data
    invalid_registration_data[:user][:login] = 'e'
    send_registration_request invalid_registration_data

    assert_response :success
    assert_template 'register'
    assert_tag :tag => 'li', :content => 'User name must have more than two characters.'
  end

  def test_should_fail_on_invalid_registration_request_with_duplicate_login
    invalid_registration_data = @valid_registration_data
    invalid_registration_data[:user][:login] = @icarus_user.login
    send_registration_request invalid_registration_data

    assert_response :success
    assert_template 'register'
    assert_tag :tag => 'li', :content => 'User name is the name of an already existing user.'
  end

  def test_should_fail_on_invalid_registration_request_with_no_password
    invalid_registration_data = @valid_registration_data
    invalid_registration_data[:password] = nil
    invalid_registration_data[:password_confirmation] = nil
    send_registration_request invalid_registration_data

    assert_response :success
    assert_tag :tag => 'li', :content => 'Password must be given'
  end

  def test_should_fail_on_invalid_registration_request_with_too_short_password
    invalid_registration_data = @valid_registration_data
    invalid_registration_data[:password] = 'short'
    invalid_registration_data[:password_confirmation] = 'short'
    send_registration_request invalid_registration_data

    assert_response :success
    assert_tag :tag => 'li', :content => 'Password must have between 6 and 64 characters'
  end

  def test_should_fail_on_invalid_registration_request_with_too_long_password
    invalid_registration_data = @valid_registration_data
    invalid_registration_data[:password] = 'e' * 101
    invalid_registration_data[:password_confirmation] = 'e' * 101
    send_registration_request invalid_registration_data

    assert_response :success
    assert_tag :tag => 'li', :content => 'Password must have between 6 and 64 characters'
  end

  def test_should_fail_on_invalid_registration_request_with_unmatching_password
    invalid_registration_data = @valid_registration_data
    invalid_registration_data[:password] = 'These Passwords'
    invalid_registration_data[:password_confirmation] = 'Don\'t Match'
    send_registration_request invalid_registration_data

    assert_response :success
    assert_tag :tag => 'li', :content => 'Password must match the confirmation.'
  end
  
  def test_should_fail_on_invalid_confirmation_request_with_invalid_user
    send_registration_request @valid_registration_data
    invalid_confirmation_data = @valid_confirmation_data
    invalid_confirmation_data[:user] = -1
    send_confirm_get_request invalid_confirmation_data
    
    assert_response :success
    assert_template 'confirm_failure'
  end

  def test_should_fail_on_invalid_confirm_post_request_with_invalid_token
    send_registration_request @valid_registration_data
    invalid_confirmation_data = @valid_confirmation_data
    invalid_confirmation_data[:token] = invalid_confirmation_data[:token] + 'INVALID'
    send_confirm_post_requests invalid_confirmation_data
    
    assert_response :success
    assert_template 'confirm_failure'
  end

  def test_should_fail_on_invalid_lost_password_post_request_with_unknown_user
    send_registration_request @valid_registration_data
    send_confirm_get_request @valid_confirmation_data

    invalid_lost_password_data = @valid_lost_password_data
    invalid_lost_password_data[:login] = invalid_lost_password_data[:login].to_s + 'INVALID'
    
    send_lost_password_request invalid_lost_password_data

    assert_response :success
    assert_template 'lostpassword'
    assert_tag :tag => 'li', :content => 'You have entered an invalid user name or an invalid email address.'
  end
  
  def test_should_fail_on_invalid_lost_password_post_request_with_wrong_email_address
    send_registration_request @valid_registration_data
    send_confirm_get_request @valid_confirmation_data
    invalid_lost_password_data = @valid_lost_password_data
    invalid_lost_password_data[:email] = invalid_lost_password_data[:email] + 'INVALID'
    send_lost_password_request invalid_lost_password_data

    assert_response :success
    assert_template 'lostpassword'
    assert_tag :tag => 'li', :content => 'You have entered an invalid user name or an invalid email address.'
  end

  def test_should_fail_on_invalid_lost_password_post_request_with_not_confirmed_user_state
    send_registration_request @valid_registration_data
    # Note: No confirmation request here on purpose!
    send_lost_password_request @valid_lost_password_data

    assert_response :success
    assert_template 'lostpassword'
    assert_tag :tag => 'li', :content => 'You have entered an invalid user name or an invalid email address.'
  end

  def test_should_redirect_to_register_on_index
    get 'index'
    
    assert_response :redirect
    assert_redirected_to :action => 'register'
  end

  # Checks that https://activerbac.turingstudio.com/trac/ticket/75 is fixed
  # and the hint is not displayed in the registration form.
  def test_should_not_display_leave_blank_hint_in_registration_form
    get :register
    
    assert_no_tag :tag => 'div', :attributes => { :class => 'hint' }, 
      :content => 'Leave empty to keep the password unchanged'
  end
end
