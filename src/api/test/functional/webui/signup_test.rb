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
      flash_message.must_equal 'The account "eisendieter" is now active.'
    end

    def test_signup_confirmation
      # Configure confirmation for signups
      change_signup_config 'confirmation'
      signup_user root_path
      flash_message.must_equal 'Thank you for signing up! An admin has to confirm your account now. Please be patient.'
    end

    def test_signup_never
      # Configure denying signups
      change_signup_config 'never'
      visit user_register_user_path
      page.must_have_content "Sorry, sign up is disabled"
    end

end

