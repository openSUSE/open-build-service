require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class SignupTest < ActionDispatch::IntegrationTest

    def test_login
      login_user("tom", "thunderz", false)

      assert page.has_text?("Please Login")
      assert page.has_text?("Authentication failed")
 
      login_user("tom", "thunder")
    end

    def test_setup_opensuse_org
      # first login as admin is redirected twice and does not get the flash
      login_user("king", "sunflower", false)

      assert page.has_text?("Connect a remote Open Build Service instance")
    end

end

