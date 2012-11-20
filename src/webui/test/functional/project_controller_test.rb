require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        
class ProjectControllerTest < ActionDispatch::IntegrationTest
  
  def test_list
    visit "/project"
    assert find('#project_list h3').text =~ %r{All Public Projects}
  end
 
  def test_show
    visit project_show_path(project: "Apache")
    assert find('#project_title')
    visit "/project/show?project=My:Maintenance"
    assert find('#project_title')
  end

  def test_packages_empty
    visit "/package/rdiff?opackage=pack2&oproject=BaseDistro2.0&package=pack2_linked&project=BaseDistro2.0"
  end

  def test_packages_kde4
    visit "/project/show?project=kde4"
  end
  
  def test_group_access_adrian_kde4
    login_adrian
    # adrian is maintainer via group on kde4 
    visit "/project/show?project=kde4"
    # really simple test to get started
    assert page.find(:xpath, '//a[@id="delete-project"]')
    assert page.find(:xpath, '//a[@id="edit-description"]')
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
  
end
