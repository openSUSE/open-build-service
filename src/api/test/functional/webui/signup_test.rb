require_relative '../../test_helper'

class Webui::SignupTest < Webui::IntegrationTest
  def signup_user(page)
    # Signup a user
    visit page
    fill_in 'login', with: 'eisendieter'
    fill_in 'email', with: 'dieter.eilts@werder.de'
    fill_in 'pwd', with: 'alemao'
    fill_in 'pwd_confirmation', with: 'alemao'
    click_button('Sign Up')
  end

  def test_signup_allow # -> spec/features/webui/sign_up_spec.rb
    signup_user root_path
    flash_message.must_equal "The account 'eisendieter' is now active."
    assert User.find_by(login: "eisendieter").is_active?
  end

  def test_signup_confirmation # -> spec/features/webui/sign_up_spec.rb
    # Configure confirmation for signups
    ::Configuration.stubs(:registration).returns("confirmation")
    signup_user root_path
    flash_message.must_equal 'Thank you for signing up! An admin has to confirm your account now. Please be patient.'
  end

  def test_signup_deny # -> spec/features/webui/sign_up_spec.rb
    # Configure denying signups
    ::Configuration.stubs(:registration).returns("deny")
    visit user_register_user_path
    page.must_have_content "Sorry, sign up is disabled"
    # but still works for admin
    login_king
    visit user_register_user_path
    page.must_have_content "Sign Up for an Open Build Service account"
  end
end
