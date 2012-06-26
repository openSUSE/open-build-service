require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

require 'webrat'

class AddRepoTest < ActionController::IntegrationTest

   def setup
      webrat_session.visit '/'
      click_link "Login"
      fill_in "Username", :with => "Iggy"
      fill_in "Password", :with => "asdfasdf"
      click_button "Login"
      assert_contain("You are logged in now")
      assert_contain("Welcome to ")
   end

   def test_add_default
     click_link 'Iggy'
     assert_response :success

     click_link 'Home Project'
     assert_response :success

     click_link 'Repositories'
     assert_contain("Repositories of home:Iggy")
     assert_contain(/i586, x86_64/)

     click_link 'Add'
     assert_contain("Add Repositories to Project home:Iggy")
     # requires javascript interaction
     #assert_contain("openSUSE Factory")
     
     assert_raise(Webrat::DisabledFieldError) do
       click_button "Add selected repositories"
     end
     # requires javascript interaction
     #check 'repo_openSUSE_Factory'
     #click_button "Add selected repositories"
     #assert_response :success
   end
   
end

