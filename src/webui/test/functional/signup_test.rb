require File.dirname(__FILE__) + '/../test_helper'

class WebratTest < ActionController::IntegrationTest

    def test_login
      logout
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "tom"
      fill_in "Password", :with => "thunderz"
      click_button "Login"
      assert_response :success
      assert_contain("Please login:")
      assert_contain("Authentication failed")
 
      fill_in "Username", :with => "tom"
      fill_in "Password", :with => "thunder"
      click_button "Login"
      assert_contain("You are logged in now")
      assert_contain("Welcome to the openSUSE Build Service")
      logout
    end

    def test_setup_opensuse_org
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "king"
      fill_in "Password", :with => "sunflower"
      click_button "Login"
      assert_contain("You are logged in now")
      assert_contain("Welcome to the openSUSE Build Service")

      click_link "Setup OBS"
      assert_contain("Connect a remote openSUSE Build Service instance")

      click_button "Save changes"
      assert_contain("Project 'openSUSE.org' was created successfully")

      logout
    end

end

