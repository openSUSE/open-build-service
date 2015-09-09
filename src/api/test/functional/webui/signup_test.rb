require_relative '../../test_helper'

class Webui::SignupTest < Webui::IntegrationTest

    def signup_user page
      # Signup a user
      visit page
      fill_in 'login', with: 'eisendieter'
      fill_in 'email', with: 'dieter.eilts@werder.de'
      fill_in 'pwd', with: 'alemao'
      click_button('Sign Up')
    end

    def change_signup_config signup
      # Change the configuration value as admin
      login_king
      config = ::Configuration.first
      config.registration = signup
      config.save!
      logout
    end

    def test_signup_allow
      signup_user root_path
      flash_message.must_equal "The account 'eisendieter' is now active."
      assert User.find_by(login: "eisendieter").is_active?
    end

    def test_signup_confirmation
      # Configure confirmation for signups
      change_signup_config 'confirmation'
      signup_user root_path
      flash_message.must_equal 'Thank you for signing up! An admin has to confirm your account now. Please be patient.'
    end

    def test_signup_deny
      # Configure denying signups
      change_signup_config 'deny'
      visit user_register_user_path
      page.must_have_content "Sorry, sign up is disabled"
      # but still works for admin
      login_king
      visit user_register_user_path
      page.must_have_content "Sign Up for an Open Build Service account"
    end
end

