require File.dirname(__FILE__) + '/../test_helper'
require 'login_controller'

# Re-raise errors caught by the controller.
class ActiveRbac::LoginController; def rescue_action(e) raise e end; end

class ActiveRbac::LoginControllerTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles, :static_permissions, :roles_static_permissions

  def setup
    @controller = ActiveRbac::LoginController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    @valid_data = {
      :login => @ariadne_user.login,
      :password => 'password'
    }
    @invalid_login_data = {
      :login => @ariadne_user.login + 'invalid',
      :password => 'password'
    }
    @invalid_password_data = {
      :login => @ariadne_user.login,
      :password => 'password' + 'invalid'
    }
  end
  
  def test_should_redirect_to_login_on_index
    get :index
    
    assert_redirected_to :action => 'login'
  end

  def test_should_display_login_form_on_login
    get :login

    assert_response :success
    assert_template 'login'
  end

  def test_should_render_success_template_on_valid_login_without_in_redirect
    post :login, :login => @valid_data[:login], :password => @valid_data[:password]
    
    assert_response :success
    assert_template 'login_success'
    assert_equal nil, flash[:notice]
    
    assert_equal @ariadne_user, session[:rbac_user]
  end

  def test_should_redirect_on_valid_login_with_return_to_in_param
    post :login, :login => @valid_data[:login], :password => @valid_data[:password],
      :return_to => '/'
    
    assert_response :redirect
    assert_redirected_to '/'
    assert_equal 'You have logged in successfully.' , flash[:notice]
    
    assert_equal @ariadne_user, session[:rbac_user]
  end
  
  def test_should_redirect_on_valid_login_with_return_to_in_session
    @request.session[:return_to] = '/'
    post :login, :login => @valid_data[:login], :password => @valid_data[:password]
    
    assert_response :redirect
    assert_redirected_to '/'
    assert_equal 'You have logged in successfully.', flash[:notice]
    
    assert_equal @ariadne_user, session[:rbac_user]
  end
  
  def test_should_prefer_session_redirect_over_param_redirect
    @request.session[:return_to] = '/'
    post :login, :login => @valid_data[:login], :password => @valid_data[:password],
      :return_to => '/foo'
    
    assert_response :redirect
    assert_redirected_to '/'
    assert_equal 'You have logged in successfully.', flash[:notice]
    assert_equal nil, session[:return_to]
    
    assert_equal @ariadne_user, session[:rbac_user]
  end
  
  def test_should_not_allow_post_to_login_with_invalid_user_login
    post :login, :login => @invalid_login_data[:login], :password => @invalid_login_data[:password]

    assert_response :success
    assert_template 'login'

    assert_nil session[:rbac_user]
  end
  
  def test_should_not_allow_post_to_login_with_invalid_password
    post :login, :login => @invalid_password_data[:login], :password => @invalid_password_data[:password]

    assert_response :success
    assert_template 'login'

    assert_nil session[:rbac_user]
  end
  
  def test_should_not_allow_post_to_login_with_invalid_states
    invalid_states_for_login = [ User.states['unconfirmed'], 
                                 User.states['locked'],
                                 User.states['deleted'] ]
    
    for state in invalid_states_for_login
      user = User.new
      user.login = "My Test User #{state}"
      user.email = 'user@localhost'
      user.password = 'password'
      user.password_confirmation = 'password'
      user.password_hash_type = User.password_hash_types[0]
      
      user.state = state
      assert user.save
      
      user.reload
      assert_equal state, user.state
      
      post 'login', :login => 'My Test User', :password => 'password'

      assert_response :success
      assert_template 'login'

      assert_nil session[:rbac_user]
    end
  end

  def test_should_display_confirmation_form_on_logout
    # first do a valid login
    test_should_render_success_template_on_valid_login_without_in_redirect

    # then request logout form
    get :logout
    
    assert_response :success
    assert_template 'logout'

    assert_equal @ariadne_user, session[:rbac_user]
  end

  def test_should_perform_logout_when_logged_in_by_post_with_yes
    # first do a valid login
    test_should_render_success_template_on_valid_login_without_in_redirect

    # then try to logout
    post :logout, :yes => 'Yes'

    assert_response :success
    assert_template 'logout_success'

    assert_nil session[:rbac_user]
  end

  def test_should_not_perform_logout_when_logged_in_by_post_with_no
    # first do a valid login
    test_should_render_success_template_on_valid_login_without_in_redirect

    # then try to logout
    post :logout, :no => 'No'

    assert_response :redirect
    assert_redirected_to '/'

    assert_equal @ariadne_user, session[:rbac_user]
  end

  def test_should_redirect_on_logout_when_not_logged_in
    get :logout

    assert_response :redirect
    assert_redirected_to '/'
  end

  def test_should_redirect_on_perform_logout_when_not_logged_in
    post :logout, :yes => 'Yes'

    assert_response :redirect
    assert_redirected_to '/'
  end
end