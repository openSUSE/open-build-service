require File.dirname(__FILE__) + '/../test_helper'

class AddRepoTest < ActionController::IntegrationTest

   def setup
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "Iggy"
      fill_in "Password", :with => "asdfasdf"
      click_button "Login"
      assert_contain("You are logged in now")
      assert_contain("Welcome to the openSUSE Build Service")
   end

   def test_add_default
     click_link 'Iggy'
     assert_response :success
  
     click_link 'Repositories'
     assert_contain("Repository Configuration")
     assert_contain(/i586, x86_64/)

     click_link 'Add'
     assert_contain("Add Repositories to Project home:Iggy")
     assert_contain("openSUSE Factory")
     
     assert_raise(Webrat::DisabledFieldError) do
       click_button "Add selected repositories"
     end
     check 'repo_openSUSE_Factory'
     # requires javascript interaction
     #click_button "Add selected repositories"
     #assert_response :success
   end
   
end

