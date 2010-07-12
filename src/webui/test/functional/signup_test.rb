require File.dirname(__FILE__) + '/../test_helper'

class WebratTest < ActionController::IntegrationTest

    def test_login
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
    end

end

