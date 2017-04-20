# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::PatchinfoControllerTest < Webui::IntegrationTest
  LONG_DESCRIPTION = "long description" * 15

  setup do
    use_js
    login_Iggy
    visit project_show_path(project: "home:Iggy")
  end

  teardown do
    login_Iggy
    delete_patchinfo('home:Iggy')
  end

  def test_create_patchinfo_with_too_short_summary # /src/api/spec/controllers/webui/patchinfo_controller_spec.rb
    click_link("Create patchinfo")
    fill_in "summary", with: "Too short"
    fill_in "description", with: LONG_DESCRIPTION
    click_button("Save Patchinfo")

    flash_message.must_equal "|| Summary is too short (should have more than 10 signs)"
    flash_message_type.must_equal :alert
  end

  def test_create_patchinfo_with_too_short_desc # /src/api/spec/controllers/webui/patchinfo_controller_spec.rb
    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: "This description is too short"
    click_button("Save Patchinfo")

    flash_message.must_equal "|| Description is too short (should have more than 50 signs and longer than summary)"
    flash_message_type.must_equal :alert
  end

  def test_create_patchinfo_with_too_short_sum_and_desc # /src/api/spec/controllers/webui/patchinfo_controller_spec.rb
    click_link("Create patchinfo")
    fill_in "summary", with: "Too short"
    fill_in "description", with: "This description is too short"
    click_button("Save Patchinfo")

    flash_message.must_equal "|| Summary is too short (should have more than 10 signs) " +
      "|| Description is too short (should have more than 50 signs and longer than summary)"
    flash_message_type.must_equal :alert
  end

  # FIXME: Split this up into separate tests and user setup, etc
  def test_accessability # /src/api/spec/controllers/webui/patchinfo_controller_spec.rb
    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION
    click_button("Save Patchinfo")

    # check that the patchinfo is not editable for unauthorized users per buttons
    login_adrian(do_assert: false)
    visit patchinfo_show_path(project: "home:Iggy", package: "patchinfo")
    page.wont_have_content("Edit patchinfo")
    page.wont_have_content("Delete patchinfo")

    # check that the patchinfo is not editable per direct url for unauthorized users
    visit patchinfo_edit_patchinfo_path(project: "home:Iggy", package: "patchinfo")
    click_button("Save Patchinfo")
    flash_message.must_equal "Sorry, you are not authorized to update this Package."
    flash_message_type.must_equal :alert

    # check that the patchinfo is not editable for anonymous user per buttons
    logout
    visit patchinfo_show_path(project: "home:Iggy", package: "patchinfo")
    page.wont_have_content("Edit patchinfo")
    page.wont_have_content("Delete patchinfo")

    # check that the patchinfo is not editable per direct url for unauthorized users
    visit patchinfo_edit_patchinfo_path(project: "home:Iggy", package: "patchinfo")
    page.must_have_text('Please Log In')
  end

  def test_create_patchinfo_with_desc_and_sum # /src/api/spec/controllers/webui/patchinfo_controller_spec.rb
    click_link("Create patchinfo")
    page.must_have_text("Patchinfo-Editor for")

    fill_in "summary", with: "This is a test for the patchinfo-editor"
    description = LONG_DESCRIPTION
    fill_in "description", with: description
    click_button("Save Patchinfo")

    flash_message.must_equal "Successfully edited patchinfo"
    page.must_have_text "recommended update for"
    page.must_have_text "This is a test for the patchinfo-editor"
    page.must_have_text "This update was submitted from #{current_user}"
    page.must_have_text "and rated as low"

    assert_equal find(:id, "description-text").text, description
    page.must_have_selector("#zypp_false")
    page.must_have_selector("#reboot_false")
    page.must_have_selector("#relogin_false")
  end

  def test_create_patchinfo_with_changed_rating_and_category
    click_link("Create patchinfo")
    page.must_have_text("Patchinfo-Editor for")

    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION
    find('select#category').select("optional")
    find('select#rating').select("critical")
    click_button("Save Patchinfo")

    flash_message.must_equal "Successfully edited patchinfo"
    page.must_have_text "optional update for"
    page.must_have_text "This update was submitted from #{current_user}"
    page.must_have_text "and rated as critical"
  end

  def test_create_patchinfo_with_flags
    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION

    find(:id, "zypp_restart_needed").click
    find(:id, "relogin").click
    find(:id, "reboot").click

    click_button("Save Patchinfo")

    flash_message.must_equal "Successfully edited patchinfo"
    page.must_have_selector("#zypp_true")
    page.must_have_selector("#relogin_true")
    page.must_have_selector("#reboot_true")
  end

  def test_create_patchinfo_with_binaries
    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION

    ["package", "delete_me"].each do |bin|
      find('select#available_binaries').select(bin)
      click_button("add")
    end
    click_button("Save Patchinfo")

    page.must_have_text "Selected binaries:"
    ["package", "delete_me"].each do |bin|
      page.must_have_text bin
    end

    click_link("Edit patchinfo")
    # remove 'delete_me' from selected binaries
    find('select#selected_binaries').select('delete_me')
    click_button("remove")
    click_button("Save Patchinfo")
    page.wont_have_text('delete_me')
  end

  def test_create_patchinfo_with_issues
    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION

    issues = ["bnc#770555", "bnc#700500"]
    fill_in "issue", with: issues.join(",")
    find(:css, "img[alt=\"Add Bug\"]").click
    find_link(issues.last)
    click_button("Save Patchinfo")

    issues.each do |issue|
      page.must_have_text issue
    end

    # now add issues with wrong formats
    click_link("Edit patchinfo")
    # no issue should be added
    fill_in "issue", with: "bgo#123456.bnc#700501"
    find(:css, "img[alt=\"Add Bug\"]").click
    page.evaluate_script('window.confirm = function() { return true; }')
    # the last issue should be added
    fill_in "issue", with: "121212,bnc#700501"
    find(:css, "img[alt=\"Add Bug\"]").click
    page.evaluate_script('window.confirm = function() { return true; }')
    page.wont_have_content("121212")
    find('a', text: "bnc#700501")
    click_button("Save Patchinfo") # FIXME: This doesn't have any effect here
  end

  def delete_patchinfo(project) # /src/api/spec/controllers/webui/patchinfo_controller_spec.rb
    visit patchinfo_show_path(package: 'patchinfo', project: project)
    return unless page.has_link?('delete-patchinfo')

    find(:id, 'delete-patchinfo').click
    find(:id, 'del-dialog').must_have_text 'Delete Confirmation'
    find_button("Ok").click

    assert_equal page.current_path, project_show_path(project)
    find('#flash-messages').must_have_text "Patchinfo was successfully removed."

    # FIXME: There must be a better way to test this
    begin
      Package.get_by_project_and_name(project.to_param, "patchinfo")
      assert false
    rescue Package::UnknownObjectError => e
      assert_equal "home:Iggy/patchinfo", e.message
    end
  end

  def test_create_patchinfo_and_edit_it # /src/api/spec/controllers/webui/patchinfo_controller_spec.rb
    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION
    click_button("Save Patchinfo")

    # edit the summary of the created patchinfo
    click_link("Edit patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION
    find('select#category').select("optional")
    find('select#rating').select("critical")
    fill_in "issue", with: "bnc#90001"
    click_button("Save Patchinfo")

    flash_message.must_equal "Successfully edited patchinfo"
    page.must_have_text "optional update for"
    page.must_have_text "This update was submitted from #{current_user}"
    page.must_have_text "and rated as critical"
  end

  def test_create_patchinfo_that_is_blocked
    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION

    find(:id, "block").click
    fill_in "block_reason", with: "I don't like it"
    click_button("Save Patchinfo")

    page.must_have_text "This update is currently blocked:"
    page.must_have_text "I don't like it"
  end

  def test_remove # /src/api/spec/controllers/webui/patchinfo_controller_spec.rb
    login_tom
    visit project_show_path(project: "home:tom")
    # Workaround until we have nice fixtures / factory girl
    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION
    click_button("Save Patchinfo")

    visit patchinfo_show_path(package: 'patchinfo', project: "home:tom")
    find(:id, "delete-patchinfo").click
    find(:id, "del-dialog").must_have_text "Delete Confirmation"
    find_button("Ok").click

    assert_equal page.current_path, project_show_path("home:tom")
    find('#flash-messages').must_have_text "Patchinfo was successfully removed."

    visit patchinfo_show_path(package: 'patchinfo', project: "home:tom")
    assert !page.has_link?('delete-patchinfo')
  end

  def test_remove_that_fails # /src/api/spec/controllers/webui/patchinfo_controller_spec.rb
    login_tom
    visit project_show_path(project: "home:tom")
    # Workaround until we have nice fixtures / factory girl
    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: LONG_DESCRIPTION
    click_button("Save Patchinfo")

    project = Project.find_by(name: "home:tom")
    Package.any_instance.stubs(:check_weak_dependencies?).returns(false)

    # the actual test...
    visit patchinfo_show_path(package: 'patchinfo', project: project.name)
    find(:id, "delete-patchinfo").click
    find(:id, "del-dialog").must_have_text "Delete Confirmation"
    find_button("Ok").click

    assert_equal page.current_path, patchinfo_show_path(package: 'patchinfo', project: project.name)
    find('#flash-messages').must_have_text "Patchinfo can't be removed"

    visit patchinfo_show_path(package: 'patchinfo', project: project.name)
    assert page.has_link?('delete-patchinfo')
  end
end
