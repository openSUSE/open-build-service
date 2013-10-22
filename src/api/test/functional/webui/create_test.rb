require 'test_helper'

class Webui::CreateProjectTest < Webui::IntegrationTest

   def setup
      super
      login_tom
   end

   def test_create_package
      visit webui_engine.project_show_path project: 'home:tom'
      page.must_have_text(/Packages \(0\)/)
      page.must_have_text(/This project does not contain any packages/)

      click_link 'Create package'
      page.must_have_text 'Create New Package for home:tom'
      fill_in 'name', :with => 'coolstuff'
      click_button 'Save changes'
   end
   
   def test_create_subproject
     visit webui_engine.project_show_path project: 'home:tom'
     click_link 'Subprojects' 
  
     page.must_have_text 'This project has no subprojects'
     click_link 'Create subproject'
     fill_in 'name', :with => 'coolstuff'
     click_button 'Create Project'
     flash_message.must_equal "Project 'home:tom:coolstuff' was created successfully"

     assert current_url.end_with?(webui_engine.project_show_path(project: "home:tom:coolstuff")), "#{current_url} not ending with coolstuff"
     find('#project_title').text.must_equal 'home:tom:coolstuff'
     find('#packages_info h2').text.must_equal 'Packages (0)'
   end
end

