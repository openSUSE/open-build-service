require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class MaintenanceWorkflowTest < ActionDispatch::IntegrationTest

  test "full maintenance workflow" do
    login_king

    visit(project_show_path(project: "BaseDistro"))

    find(:id, "advanced_tabs_trigger").click
    find(:link, "Attributes").click
    find(:id, "add-new-attribute").click
    find(:id, 'attribute').select("OBS:Maintained")
    find_button("Save attribute").click

    logout
    # now let tom branch a package
    login_tom

    visit(project_show_path(project: "My:Maintenance"))
    find(:id, "project_title").text.must_equal "official maintenance space"

    find(:id, "infos_list").must_have_text %r{3 maintained projects}

    find(:link, "maintained projects").click
    find(:link, "BaseDistro2.0:LinkedUpdateProject").click

    find(:css, "#infos_list").must_have_text %r{Maintained by My:Maintenance}
    first(:link, "pack2").click
    find(:link, "Branch package").click

    find(:css, "#branch_dialog").must_have_text %r{Do you really want to branch package}
    find_button("Ok").click

    find(:css, "#flash-messages").must_have_text %r{Branched package BaseDistro2\.0:LinkedUpdateProject.*pack2}

    visit(project_show_path(project: "home:tom"))

    find(:link, "Subprojects").click
    find(:link, "branches:BaseDistro2.0:LinkedUpdateProject").click
    find(:link, "Submit as update").click

    # wait for the dialog to appear
    find(:css, ".dialog h2").must_have_text "Submit as Update"
    fill_in "description", with: "I want the update"
    find_button("Ok").click

    find(:css, "span.ui-icon.ui-icon-info").text.must_equal "Created maintenance release request"
    find(:link, "open request").text.must_equal "open request"
    find(:link, "1 Release Target").text.must_equal "1 Release Target"

    logout

    # now let the coordinator act
    login_user("maintenance_coord", "power")
    visit(project_show_path(project: "My:Maintenance"))

    find(:link, "open request").click
    find(:id, "description_text").text.must_equal "I want the update"
    fill_in "reason", with: "really? ok"
    find(:id, "accept_request_button").click
    find(:css, "#action_display_0").must_have_text %r{Submit update from package home:tom:branches:BaseDistro2.0:LinkedUpdateProject / pack2 to project My:Maintenance:0}

    visit(project_show_path(project: "My:Maintenance:0"))
    find(:link, "Patchinfo present").click
    find(:id, "edit-patchinfo").click

    find(:id, "summary").text.must_equal "I want the update"
    fill_in "summary", with: "pack2: Fixes nothing"

    fill_in "summary", with: "Nada"
    fill_in "description", with: "Fixes nothing"
    find(:id, 'rating').select("critical")
    find(:id, "relogin").click
    find(:id, "reboot").click
    find(:id, "zypp_restart_needed").click
    find(:id, "block_reason")['disabled'].must_equal false
    find(:id, "block").click
    fill_in "block_reason", with: "locked!"
    find_button("Save Patchinfo").click

    find(:css, "span.ui-icon.ui-icon-alert").must_have_text %r{Summary is too short}
    fill_in "summary", with: "pack2 is much better than the old one"
    find_button("Save Patchinfo").click

    find(:css, "span.ui-icon.ui-icon-alert").must_have_text %r{Description is too short}
    fill_in "description", with: "Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing, Fixes nothing"
    fill_in "issue", with: "bnc#272722"
    find(:css, "img[alt=\"Add Bug\"]").click
    # wait till issue is added
    find_link("bnc#272722")
    find_button("Save Patchinfo").click

    # summary and description are ok now
    page.wont_have_selector "span.ui-icon.ui-icon-alert"

    find(:css, "span.ui-icon.ui-icon-info").text.must_equal "Successfully edited patchinfo"
    find(:css, ".ui-state-error b").text.must_equal "This update is currently blocked:"

    find(:link, "My:Maintenance").click
    find(:link, "open incident").click
    select("closed", from: "incident_type_select")
    select("open", from: "incident_type_select")

    find(:link, "recommended").click
    find(:id, "edit-patchinfo").click
    find(:id, "block").click
    find(:id, "block_reason")['disabled'].must_equal true
    click_button "Save Patchinfo"

    find(:link, "My:Maintenance").click
    find(:link, "Incidents").click
    #TODO: make it unique find(:link, "0").click
    visit project_show_path "My:Maintenance:0"
    find(:link, "Request to release").click

    fill_in "description", with: "RELEASE!"
    click_button "Ok"

    # we can't release without build results
    assert_equal "The repository 'My:Maintenance:0' / 'BaseDistro2.0_LinkedUpdateProject' / i586", find(:css, "span.ui-icon.ui-icon-alert").text
  end

end
