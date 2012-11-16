class TC24__Groups < TestCase

  test :watchlists do
    navigate_to ProjectOverviewPage, 
      :user => $data[:user1],
      :project => "BaseDistro"

    # assert watchlist is empty
    $page.driver.execute_script("$('#menu-favorites').show();")
    assert_equal 0, $page.driver.find_elements(:css, "span.icons-project").count

    $page.driver.execute_script("$('#menu-favorites').show();")

    assert_match /^[\s\S]*Add this project to Watchlist[\s\S]*$/, $page.driver.find_element(:css, "#menu-favorites").text
    $page.driver.find_element(:css, "#toggle_watch > span").click
    $page.driver.execute_script("$('#menu-favorites').show();")

    assert_equal "BaseDistro", $page.driver.find_element(:css, "span.icons-project").text
    assert_match /^[\s\S]*Remove this project from Watchlist[\s\S]*$/, $page.driver.find_element(:css, "#menu-favorites").text
    $page.driver.find_element(:css, "#toggle_watch > span").click
    wait_for_page
    $page.driver.execute_script("$('#menu-favorites').show();")
    assert_match /^[\s\S]*Add this project to Watchlist[\s\S]*$/, $page.driver.find_element(:css, "#menu-favorites").text
    $page.driver.find_element(:css, "#toggle_watch > span.desc").click
    wait_for_page

    $page.driver.find_element(:link, "Projects").click
    wait_for_page
    $page.driver.find_element(:link, "My:Maintenance").click
    wait_for_page

    $page.driver.execute_script("$('#menu-favorites').show();")
    assert_match /^[\s\S]*Add this project to Watchlist[\s\S]*$/, $page.driver.find_element(:css, "#menu-favorites").text
    $page.driver.find_element(:css, "#toggle_watch > span.desc").click
    wait_for_page

    $page.driver.execute_script("$('#menu-favorites').show();")
    $page.driver.find_element(:css, "span.icons-project").click
    wait_for_page

    assert_match /^[\s\S]*This is a base distro[\s\S]*$/, $page.driver.find_element(:css, "#project_title").text
    # teardown
    $page.driver.execute_script("$('#menu-favorites').show();")
    $page.driver.find_element(:css, "#toggle_watch > span.desc").click
    $page.driver.execute_script("$('#menu-favorites').show();")
    $page.driver.find_element(:link, "My:Maintenance").click
    $page.driver.execute_script("$('#menu-favorites').show();")
    $page.driver.find_element(:css, "#toggle_watch > span.desc").click
    assert_equal 0, $page.driver.find_elements(:css, "span.icons-project").count
  end

end
