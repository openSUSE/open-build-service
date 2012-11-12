require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CreateProjectTest < ActionDispatch::IntegrationTest

   def setup
      super
      login_tom
   end

   def test_create_package
      visit '/project/show?project=home:tom'
      assert page.has_text?(/Packages \(0\)/)
      assert page.has_text?(/This project does not contain any packages/)

      click_link 'Create package'
      assert page.has_text? 'Create New Package for home:tom'
      fill_in 'name', :with => 'coolstuff'
      click_button 'Save changes'
   end
   
   def test_create_subproject
     visit '/project/show?project=home:tom'
     click_link 'Subprojects' 
  
     assert page.has_text? 'This project has no subprojects'
     click_link 'Create subproject'
     fill_in 'name', :with => 'coolstuff'     
     click_button 'Create Project'

     assert current_url.end_with? "/project/show?project=home%3Atom%3Acoolstuff"
     assert_equal 'home:tom:coolstuff', find('#project_title').text
     assert_equal 'Packages (0)', find('#packages_info h2').text
   end
end

