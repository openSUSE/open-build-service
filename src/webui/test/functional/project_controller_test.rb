require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        
class ProjectControllerTest < ActionDispatch::IntegrationTest
  
  test "public projects" do
    visit "/project"
    assert find('#project_list h3').text =~ %r{All Public Projects}
  end
 
  test "project show" do
    visit project_show_path(project: "Apache")
    assert find('#project_title')
    visit "/project/show?project=My:Maintenance"
    assert find('#project_title')
  end

  test "diff is empty" do
    visit "/package/rdiff?opackage=pack2&oproject=BaseDistro2.0&package=pack2_linked&project=BaseDistro2.0"
    assert find('#content').has_text? "No source changes!"
  end

  test "kde4 has two packages" do
    visit "/project/show?project=kde4"
    assert find('#packages_info').has_text? "Packages (2)"
    within('#packages_info') do
      assert find_link('kdebase')
      assert find_link('kdelibs')
    end
  end
  
  test "adrian can edit kde4" do
    login_adrian
    # adrian is maintainer via group on kde4 
    visit "/project/show?project=kde4"
    # really simple test to get started
    assert page.find_link('delete-project')
    assert page.find_link('edit-description')
  end

  def create_subproject
    login_tom
    visit project_subprojects_path(project: "home:tom")
    #find(:link, "Subprojects").click
    find(:id, "link-create-subproject").click
  end

  test "create project publish disabled" do
    create_subproject
    fill_in "name", with: "coolstuff"
    find(:id, "disable_publishing").click
    find_button("Create Project").click
    find(:link, "Repositories").click
    # publish disabled icon should appear
    assert find(:css, "div.icons-publish_disabled_blue")
  end
  
  test "create hidden project" do
    create_subproject
    
    fill_in "name", with: "hiddenstuff"
    find(:id, "access_protection").click
    find_button("Create Project").click
    
    find(:id, "advanced_tabs_trigger").click
    find(:link, "Meta").click
    
    assert find(:css, "div.CodeMirror-lines").has_text? %r{<access> <disable/> </access>}

    # now check that adrian can't see it
    logout
    login_adrian
    
    visit project_subprojects_path(project: "home:tom")    

    assert page.has_no_text? "hiddenstuff"
  end
  
  test "delete subproject redirects to parent" do
    create_subproject
    fill_in "name", with: "toberemoved"
    find_button("Create Project").click

    find(:id, 'delete-project').click
    find_button('Ok').click
    # now the actual assertion :)
    assert page.current_url.end_with? project_show_path(project: "home:tom")
  end

  test "delete home project" do
    login_user("user1", "123456")
    visit project_show_path(project: "home:user1")
    # now on to a suprise - the project needs to be created on first login
    find_button("Create Project").click

    find(:id, 'delete-project').click
    find_button('Ok').click

    assert find('#flash-messages').has_text? "Project 'home:user1' was removed successfully"
    # now the actual assertion :)
    assert page.current_url.end_with? project_list_public_path
  end

  test "admin can delete every project" do
    login_king
    visit project_show_path(project: "LocalProject")
    find(:id, 'delete-project').click
    find_button('Ok').click

    assert find('#flash-messages').has_text? "Project 'LocalProject' was removed successfully"
    assert page.current_url.end_with? project_list_public_path
    assert find('#project_list').has_no_text? 'LocalProject'

    # now that it worked out we better make sure to recreate it.
    # The API database is rolled back on test end, but the backend is not
    visit project_new_path
    fill_in 'name', with: 'LocalProject'
    find_button('Create Project').click
  end
end
