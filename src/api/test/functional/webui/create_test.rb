require_relative '../../test_helper'

class Webui::CreateProjectTest < Webui::IntegrationTest
  uses_transaction :test_create_subproject

  def test_create_package # spec/features/webui/projects_spec.rb
    login_tom to: project_show_path(project: 'home:tom')
    page.must_have_text(/Packages \(0\)/)
    page.must_have_text(/This project does not contain any packages/)

    click_link 'Create package'
    page.must_have_text 'Create New Package for home:tom'
    fill_in 'name', with: 'coolstuff'
    click_button 'Save changes'
  end

  def test_create_subproject # spec/features/webui/projects_spec.rb
    login_tom to: project_show_path(project: 'home:tom')
    click_link 'Subprojects'

    page.must_have_text 'This project has no subprojects'
    click_link 'create_subproject_link'
    fill_in 'project_name', with: 'coolstuff'
    click_button 'Create Project'
    flash_message.must_equal "Project 'home:tom:coolstuff' was created successfully"

    assert current_url.end_with?(project_show_path(project: 'home:tom:coolstuff')), "#{current_url} not ending with coolstuff"
    find('#project_title').text.must_equal 'home:tom:coolstuff'
    first('#packages li').text.must_equal 'Packages (0)'
  end
end
