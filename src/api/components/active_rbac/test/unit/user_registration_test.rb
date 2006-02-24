require File.dirname(__FILE__) + '/../test_helper'

# TODO: Test timestamps

class UserRegistrationTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles
  
  #
  # The tests
  #
  
  def setup
    @user = User.new
    @user.login = 'My New User'
    @user.email = 'user@localhost'
    @user.update_password 'password'
  end

  def test_should_be_createable_by_user_objects
    user = @user
    
    assert user.save
    assert user.reload

    user.create_user_registration

    assert_equal User.states['unconfirmed'], user.state
    assert_not_nil user.user_registration
    assert_kind_of Time, user.user_registration.created_at
    assert_kind_of Time, user.user_registration.expires_at
    assert_in_delta user.user_registration.created_at + 1.day, user.user_registration.expires_at, 2
    assert_not_nil user.user_registration.token
  end
  
  def test_should_allow_confirmation_with_valid_token
    test_should_be_createable_by_user_objects
    user = @user
    
    user.reload
    
    assert user.confirm_registration(user.user_registration.token)
    assert_equal User.states['confirmed'], user.state
    assert user.user_registration.frozen?
    # user.user_registration won't be nil, but it is frozen so it has been deleted
    assert_raise(ActiveRecord::RecordNotFound) { UserRegistration.find user.user_registration.id }
  end
end