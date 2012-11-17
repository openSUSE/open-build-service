class TC25__Maintenance < TestCase

  test :setup_for_maintenance do
    depend_on :login_as_admin

    navigate_to ProjectOverviewPage, 
      :user => $data[:admin],
      :project => "BaseDistro"

    $page.driver.find_element(:id, "advanced_tabs_trigger").click
    $page.driver.find_element(:link, "Attributes").click
    wait_for_page
    $page.driver.find_element(:id, "add-new-attribute").click
    wait_for_page
    Selenium::WebDriver::Support::Select.new($page.driver.find_element(:id, "attribute")).select_by(:text, "OBS:Maintained")
    $page.driver.find_element(:name, "commit").click

    navigate_to ProjectOverviewPage, user: :none, project: "My:Maintenance"
    assert_equal "official maintenance space", $page.driver.find_element(:id, "project_title").text
    
    assert_match /^[\s\S]*3 maintained projects[\s\S]*$/, $page.driver.find_element(:css, "BODY").text
  end

  test :let_packager_branch_a_maintained_package do
    depend_on :setup_for_maintenance
    
    navigate_to ProjectOverviewPage, user: $data[:user1], project: "My:Maintenance"
    $page.driver.find_element(:link, "maintained projects").click
    wait_for_page
    $page.driver.find_element(:link, "BaseDistro2.0:LinkedUpdateProject").click
    wait_for_page 
    
    assert_match %r{Maintained by My:Maintenance}, $page.driver.find_element(:css, "#infos_list").text
    $page.driver.find_element(:link, "pack2").click
    wait_for_page
    $page.driver.find_element(:link, "Branch package").click
    wait_for_javascript
    assert_match %{Do you really want to branch package}, $page.driver.find_element(:css, "#branch_dialog").text
    $page.driver.find_element(:name, "commit").click
    wait_for_page

    assert_match %r{Branched package BaseDistro2\.0:LinkedUpdateProject.*pack2}, $page.driver.find_element(:css, "#flash-messages").text

  end
  
  test :packager_submits_the_update do
    depend_on :let_packager_branch_a_maintained_package, :create_home_project_for_user
    
    navigate_to ProjectOverviewPage, user: $data[:user1], project: "home:user1"

    $page.driver.find_element(:link, "Subprojects").click
    wait_for_page
    $page.driver.find_element(:link, "branches:BaseDistro2.0:LinkedUpdateProject").click
    wait_for_page
    $page.driver.find_element(:link, "Submit as update").click
    wait_for_javascript
    $page.driver.find_element(:id, "description").clear
    $page.driver.find_element(:id, "description").send_keys "I want the update"
    $page.driver.find_element(:name, "commit").click
    wait_for_page
    assert_equal "Created maintenance release request", $page.driver.find_element(:css, "span.ui-icon.ui-icon-info").text
    assert_equal "open request", $page.driver.find_element(:link, "open request").text
    assert_equal "1 Release Target", $page.driver.find_element(:link, "1 Release Target").text

    $page.driver.find_element(:link, "Create patchinfo").click
    wait_for_page
    $page.driver.find_element(:id, "summary").clear
    $page.driver.find_element(:id, "summary").send_keys "Nada"
    $page.driver.find_element(:id, "description").clear
    $page.driver.find_element(:id, "description").send_keys "Fixes nothing"
    Selenium::WebDriver::Support::Select.new($page.driver.find_element(:id, "rating")).select_by(:text, "critical")
    $page.driver.find_element(:id, "relogin").click
    $page.driver.find_element(:id, "reboot").click
    $page.driver.find_element(:id, "zypp_restart_needed").click
    $page.driver.find_element(:id, "block").click
    $page.driver.find_element(:id, "block_reason").clear
    $page.driver.find_element(:id, "block_reason").send_keys "locked!"
    $page.driver.find_element(:name, "commit").click
    wait_for_page
    assert_match %r{Summary is too short}, $page.driver.find_element(:css, "span.ui-icon.ui-icon-alert").text
    $page.driver.find_element(:id, "summary").clear
    $page.driver.find_element(:id, "summary").send_keys "pack2 is much better than the old one"
    $page.driver.find_element(:name, "commit").click
    wait_for_page
    assert_match %r{Description is too short}, $page.driver.find_element(:css, "span.ui-icon.ui-icon-alert").text
    $page.driver.find_element(:id, "description").clear
    $page.driver.find_element(:id, "description").send_keys "Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing"
    $page.driver.find_element(:id, "issue").clear
    $page.driver.find_element(:id, "issue").send_keys "bnc#27272"
    $page.driver.find_element(:css, "img[alt=\"Add Bug\"]").click
    wait_for_javascript
    $page.driver.find_element(:name, "commit").click
    wait_for_page
    assert_equal "Successfully edited patchinfo", $page.driver.find_element(:css, "span.ui-icon.ui-icon-info").text
    assert_equal "This update is currently blocked:", $page.driver.find_element(:css, "b").text

  end
  
  test :let_the_hero_work do
    depend_on :packager_submits_the_update 

    navigate_to ProjectOverviewPage, user: $data[:hero], project: "My:Maintenance"
    
    $page.driver.find_element(:link, "open request").click
    wait_for_page
    assert_equal "I want the update", $page.driver.find_element(:id, "description").text
    $page.driver.find_element(:id, "reason").click
    $page.driver.find_element(:id, "reason").clear
    $page.driver.find_element(:id, "reason").send_keys "really? ok"
    $page.driver.find_element(:id, "accept_request_button").click
    wait_for_page
    $page.driver.find_element(:link, "My:Maintenance:0").click
    wait_for_page
    $page.driver.find_element(:link, "Patchinfo present").click
    wait_for_page
    $page.driver.find_element(:id, "edit-patchinfo").click
    wait_for_page
    # TODO: need to find out if this is correct or buggy
    skip

    assert_equal "Fixes nothing", $page.driver.find_element(:id, "summary").text
    $page.driver.find_element(:id, "summary").clear
    $page.driver.find_element(:id, "summary").send_keys "pack2: Fixes nothing"
    $page.driver.find_element(:name, "commit").click
    wait_for_page
    $page.driver.find_element(:link, "My:Maintenance").click
    $page.driver.find_element(:link, "open incident").click
    Selenium::WebDriver::Support::Select.new($page.driver.find_element(:id, "incident_type_select")).select_by(:text, "closed")
    Selenium::WebDriver::Support::Select.new($page.driver.find_element(:id, "incident_type_select")).select_by(:text, "open")
    $page.driver.find_element(:link, "recommended").click
    $page.driver.find_element(:id, "edit-patchinfo").click
    $page.driver.find_element(:id, "block").click
    $page.driver.find_element(:id, "block_reason").clear
    $page.driver.find_element(:id, "block_reason").send_keys "blocking"
    $page.driver.find_element(:name, "commit").click
    wait_for_page
    assert_equal "This update is currently blocked:", $page.driver.find_element(:css, "b").text
    $page.driver.find_element(:link, "My:Maintenance").click
    $page.driver.find_element(:link, "Incidents").click
    $page.driver.find_element(:link, "0").click
    $page.driver.find_element(:link, "Request to release").click
    wait_for_javascript
    $page.driver.find_element(:id, "description").clear
    $page.driver.find_element(:id, "description").send_keys "RELEASE!"
    $page.driver.find_element(:name, "commit").click
    wait_for_page
    
    # we can't release without build results
    assert_equal "The repository 'My:Maintenance:0' / 'BaseDistro2.0_LinkedUpdateProject' / i586", $page.driver.find_element(:css, "span.ui-icon.ui-icon-alert").text
  end
  
end
