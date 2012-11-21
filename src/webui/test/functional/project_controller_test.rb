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

  test "request project repository target removal" do
    # Let user1 create a project with a repo that others can request to delete
    login_adrian
    visit project_show_path(project: "home:adrian")
    find(:link, "Subprojects").click
    find(:link, "Create subproject").click
    fill_in "name", with: "hasrepotoremove"
    find_button("Create Project").click
    find(:link, "Repositories").click
    find(:link, "Add repositories").click
    find(:id, "repo_images").click # aka "KIWI image build" checkbox
    find_button("Add selected repositories").click
    logout

    # check that anonymous has no links
    visit project_show_path(project: "home:adrian:hasrepotoremove")
    assert page.has_no_link?("Request repository deletion")
    assert page.has_no_link?("Remove repository")

    # Now let tom create the repository delete request:
    login_tom
    visit project_show_path(project: "home:adrian:hasrepotoremove")
    find(:link, "Repositories").click
    find(:link, "Request repository deletion").click
    # Wait for the dialog to appear
    assert find(:css, ".dialog h2").has_content? "Create Repository Delete Request"
    fill_in "description", with: "I don't like the repo"
    find_button("Ok").click
    assert find(:css, "span.ui-icon.ui-icon-info").has_text? "Created repository delete request"
    logout

    # Finally, user1 should accept the request and make sure the repo is gone
    login_adrian
    visit project_show_path(project: "home:adrian:hasrepotoremove")
    find("#tab-requests a").click # The project tab "Requests"
    find(".request_link").click # Should be the first and only request for this project
    assert_equal "I don't like the repo", find(:id, "description_text").text
    fill_in "reason", with: "really? ok"
    find(:id, "accept_request_button").click
    visit project_show_path(project: "home:adrian:hasrepotoremove")
    find(:link, "Repositories").click
    assert first(:id, "images").nil?  # The repo "images" should be gone by now
  end

end
