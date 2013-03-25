require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class RequestControllerTest < ActionDispatch::IntegrationTest

  def setup
    super
    login_Iggy
  end

  def test_my_involved_requests
    visit "/home/requests?user=king"

    page.must_have_selector "table#request_table tr"

    # walk over the table
    rs = find('tr#tr_request_997_1').find('.request_target')
    rs.find(:xpath, '//a[@title="kde4"]').must_have_text "kde4"
    rs.find(:xpath, '//a[@title="kdelibs"]').must_have_text "kdelibs"
  end

  test "can request role addition for projects" do
    visit project_show_path(project: "home:tom")
    click_link "Request role addition"
    find(:id, "role").select("Bugowner")
    fill_in "description", with: "I can fix bugs too."
    click_button "Ok"
    # request created
    page.must_have_text "Iggy Pop (Iggy) wants the role bugowner for project home:tom"
    find("#description_text").must_have_text "I can fix bugs too."
    page.must_have_selector("input[@name='revoked']")
    page.must_have_text("In state new")

    logout
    login_tom
    visit "/request/show/1001"
    page.must_have_text "Iggy Pop (Iggy) wants the role bugowner for project home:tom"
    click_button "Accept"
  end

  test "can request role addition for packages" do
    visit package_show_path(project: "home:Iggy", package: "TestPack")
    # no need for "request role"
    page.wont_have_link "Request role addition"
    # foreign package
    visit package_show_path(project: "Apache", package: "apache2")
    click_link "Request role addition"
    find(:id, "role").select("Maintainer")
    fill_in "description", with: "I can fix bugs too."
    click_button "Ok"
    # request created
    find("#action_display_0").must_have_text "Iggy Pop (Iggy) wants the role maintainer for package Apache / apache2"
    find("#description_text").must_have_text "I can fix bugs too."
    page.must_have_selector("input[@name='revoked']")
    page.must_have_text("In state new")


    logout
    login_tom
    visit "/request/show/1001"
    find("#action_display_0").must_have_text "Iggy Pop (Iggy) wants the role maintainer for package Apache / apache2"
    # tom is not apache maintainer
    page.wont_have_button "Accept"
    
    logout 
    login_fred
    visit "/request/show/1001"
    find("#action_display_0").must_have_text "Iggy Pop (Iggy) wants the role maintainer for package Apache / apache2"
    click_button "Accept"

    # now check the role addition link is gone
    logout
    login_Iggy
    visit package_show_path(project: "Apache", package: "apache2")
    page.wont_have_link "Request role addition"

  end 
end
