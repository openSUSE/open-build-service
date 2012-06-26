require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ChangePackageTest < ActionController::IntegrationTest

   def setup
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "Iggy"
      fill_in "Password", :with => "asdfasdf"
      click_button "Login"
      follow_redirect!
      assert_contain("You are logged in now")
      assert_contain("Welcome to ")
   end

   def test_add_and_submit_file
     fill_in 'search', :with => 'kdelibs'
     click_button 'Search'
     assert_contain("project home:coolo:test")
     
     click_link 'kdelibs_DEVEL_package'

## FIXME: we need to switch the test suite engine, to be able to test java script code as well

#     click_link 'Branch Package'
#     
#     assert_contain("Branched package home:coolo:test / kdelibs_DEVEL_package")
#     click_link 'Files'
#     assert_response :success
#
#     click_link 'Add file'
     
   end
   
end

