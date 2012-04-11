require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CreateProjectTest < ActionController::IntegrationTest

   def setup
      visit '/'
      click_link "Login"
      fill_in "Username", :with => "tom"
      fill_in "Password", :with => "thunder"
      click_button "Login"
      assert_contain("You are logged in now")
      assert_contain("Welcome to ")
   end

   def test_create_package
      visit '/project/show?project=home:tom'
      assert_contain(/Packages (0)/)
      
      click_link 'Packages'
      assert_contain(/This project does not contain any packages/)

      click_link 'Create package'
      assert_contain 'Create New Package for home:tom'
      fill_in 'name', :with => 'coolstuff'
      click_button 'Save changes'
      assert_response :success
   end
   
   def test_create_subproject
     visit '/project/show?project=home:tom'
     click_link 'Subprojects' 
     assert_response :success
  
     assert_contain 'This project has no subprojects'
     click_link 'Create subproject'
     fill_in 'name', :with => 'coolstuff'     
     click_button 'Create Project'
     assert_response :success 

     assert_contain 'home:tom:coolstuff'
     assert_contain(/Packages (0)/)
   end
end

