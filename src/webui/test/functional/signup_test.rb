require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class WebratTest < ActionController::IntegrationTest

    def test_login
      logout
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "tom"
      fill_in "Password", :with => "thunderz"
      click_button "Login"
      assert_response :success
      assert_contain("Please Login")
      assert_contain("Authentication failed")
 
      fill_in "Username", :with => "tom"
      fill_in "Password", :with => "thunder"
      click_button "Login"
      assert_contain("You are logged in now")
      logout
    end

    def test_setup_opensuse_org
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "king"
      fill_in "Password", :with => "sunflower"
      click_button "Login"
      assert_contain("You are logged in now")

      click_link "Configuration"
      assert_contain("Connect to a remote OBS instance")
      logout
    end

end

