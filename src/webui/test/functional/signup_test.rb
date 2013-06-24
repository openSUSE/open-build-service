require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class SignupTest < ActionDispatch::IntegrationTest

    def test_login
      login_user("tom", "thunderz", false)

      page.must_have_text("Please Log In")
      page.must_have_text("Authentication failed")
 
      login_user("tom", "thunder")
    end

end

