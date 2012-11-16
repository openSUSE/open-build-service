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
  
end
