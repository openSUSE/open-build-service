require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class SignupTest < ActionController::IntegrationTest

    def test_login
      logout
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "tom"
      fill_in "Password", :with => "thunderz"

      click_button "Login"
      assert_contain("Please Login")
      assert_contain("Authentication failed")
 
      fill_in "Username", :with => "tom"
      fill_in "Password", :with => "thunder"
      click_button "Login"
      follow_redirect!
      assert_contain("You are logged in now")
      logout
    end

    def test_setup_opensuse_org
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "king"
      fill_in "Password", :with => "sunflower"
      click_button "Login"
      follow_redirect!
      # first login as admin is redirected twice
      follow_redirect!
      #assert_contain("You are logged in now")

      assert_contain("Connect a remote Open Build Service instance")
      logout
    end

end

