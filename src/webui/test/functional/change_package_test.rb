require File.dirname(__FILE__) + '/../test_helper'

class ChangePackageTest < ActionController::IntegrationTest

   def setup
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "Iggy"
      fill_in "Password", :with => "asdfasdf"
      click_button "Login"
      assert_contain("You are logged in now")
      assert_contain("Welcome to the openSUSE Build Service")
   end

   def test_add_and_submit_file
     fill_in 'search', :with => 'kdelibs'
     click_button 'Search'
     assert_response :success
     assert_contain("project home:coolo:test")
     
     click_link 'kdelibs_DEVEL_package'
     click_link 'Branch package'
     
     assert_contain("Branched package home:coolo:test / kdelibs_DEVEL_package")
     click_link 'Files'
     
   end
   
end

