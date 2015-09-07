# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::PatchinfoCreateTest < Webui::IntegrationTest

  LONG_DESCRIPTION = "long description" * 15

  setup do
    use_js
    @project = 'home:Iggy'
  end

  def test_create_patchinfo_with_too_short_summary
    login_Iggy
    visit project_show_path(project: "home:Iggy")

    click_link("Create patchinfo")
    fill_in "summary", with: "Too short"
    fill_in "description", with: LONG_DESCRIPTION
    click_button("Save Patchinfo")

    flash_message.must_equal "|| Summary is too short (should have more than 10 signs)"
    flash_message_type.must_equal :alert

    delete_patchinfo('home:Iggy')
  end

  def test_create_patchinfo_with_too_short_desc
    login_Iggy
    visit project_show_path(project: "home:Iggy")

    click_link("Create patchinfo")
    fill_in "summary", with: "This is a test for the patchinfo-editor"
    fill_in "description", with: "This description is too short"
    click_button("Save Patchinfo")

    flash_message.must_equal "|| Description is too short (should have more than 50 signs and longer than summary)"
    flash_message_type.must_equal :alert

    delete_patchinfo('home:Iggy')
  end

  def test_create_patchinfo_with_too_short_sum_and_desc
    login_Iggy
    visit project_show_path(project: "home:Iggy")

    click_link("Create patchinfo")
    fill_in "summary", with: "Too short"
    fill_in "description", with: "This description is too short"
    click_button("Save Patchinfo")

    flash_message.must_equal "|| Summary is too short (should have more than 10 signs) " +
      "|| Description is too short (should have more than 50 signs and longer than summary)"
    flash_message_type.must_equal :alert

    delete_patchinfo('home:Iggy')
  end

  # FIXME: Split this up into separate tests and user setup, etc
  def test_accessability
    login_Iggy
    visit project_show_path(project: "home:Iggy")

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
    flash_message.must_equal "No permission to edit the patchinfo-file."
    flash_message_type.must_equal :alert

    # check that the patchinfo is not editable for anonymous user per buttons
    logout
    visit patchinfo_show_path(project: "home:Iggy", package: "patchinfo")
    page.wont_have_content("Edit patchinfo")
    page.wont_have_content("Delete patchinfo")

    # check that the patchinfo is not editable per direct url for unauthorized users
    visit patchinfo_edit_patchinfo_path(project: "home:Iggy", package: "patchinfo")
    page.must_have_text('Please Log In')

    # Cleanup
    login_Iggy
    delete_patchinfo('home:Iggy')
  end

  def test_create_patchinfo_with_desc_and_sum
    login_Iggy
    visit project_show_path(project: "home:Iggy")

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

    assert_equal find(:id, "description_text").text, description
    page.must_have_selector("#zypp_false")
    page.must_have_selector("#reboot_false")
    page.must_have_selector("#relogin_false")

    delete_patchinfo('home:Iggy')
  end

  def test_create_patchinfo_with_changed_rating_and_category
    login_Iggy
    visit project_show_path(project: "home:Iggy")

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

    delete_patchinfo('home:Iggy')
  end

  def test_create_patchinfo_with_flags
    login_Iggy
    visit project_show_path(project: "home:Iggy")

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

    delete_patchinfo('home:Iggy')
  end

  def test_create_patchinfo_with_binaries
    login_Iggy
    visit project_show_path(project: "home:Iggy")

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
    #remove 'delete_me' from selected binaries
    find('select#selected_binaries').select('delete_me')
    click_button("remove")
    click_button("Save Patchinfo")
    page.wont_have_text('delete_me')

    delete_patchinfo('home:Iggy')
  end

  def open_new_patchinfo
    click_link("Create patchinfo")
    page.must_have_text "Patchinfo-Editor for "
  end

  def create_patchinfo_for_test new_patchinfo
    new_patchinfo[:expect] ||= :success
    new_patchinfo[:packager] ||= current_user
    new_patchinfo[:summary] ||= ""
    new_patchinfo[:description] ||= ""

    new_patchinfo[:description].squeeze!(" ")
    new_patchinfo[:description].gsub!(/ *\n +/, "\n")
    new_patchinfo[:description].strip!
    assert Patchinfo::CATEGORIES.include? new_patchinfo[:category]
    find('select#category').select(new_patchinfo[:category])
    assert Patchinfo::RATINGS.include? new_patchinfo[:rating]
    find('select#rating').select(new_patchinfo[:rating])
    new_patchinfo[:issue] ||= ""

    new_patchinfo[:block] ||= false
    new_patchinfo[:block_reason] ||= ""

    fill_in "summary", with: new_patchinfo[:summary]
    fill_in "description", with: new_patchinfo[:description]
    if !new_patchinfo[:issue].blank?
      fill_in "issue", with: new_patchinfo[:issue]
      find(:css, "img[alt=\"Add Bug\"]").click
      issues = new_patchinfo[:issue].gsub(/\s+/, "").split(",")
      find_link(issues.last)
    end

    find(:id, "block").click if new_patchinfo[:block]
    fill_in new_patchinfo[:block_reason], with: new_patchinfo[:block_reason] if new_patchinfo[:block] and new_patchinfo[:block_reason]

    click_button("Save Patchinfo")

    if new_patchinfo[:expect] == :success
      flash_message.must_equal "Successfully edited patchinfo"
      new_patchinfo[:description] = "No description set" if new_patchinfo[:description].empty?
      page.must_have_text "#{new_patchinfo[:category]} update for"
      page.must_have_text "#{new_patchinfo[:summary]}"
      page.must_have_text "This update was submitted from "
      page.must_have_text "#{new_patchinfo[:packager]}"
      page.must_have_text " and rated as #{new_patchinfo[:rating]}"
      if !new_patchinfo[:issue].blank?
        issues = new_patchinfo[:issue].gsub(/\s+/, "").split(",")
        issues.each do |issue|
          page.must_have_text issue
        end
      end
      assert_equal new_patchinfo[:description].gsub(%r{\s+}, ' '), find(:id, "description_text").text
      page.must_have_selector("#zypp_false")
      page.must_have_selector("#reboot_false")
      page.must_have_selector("#relogin_false")
    end
  end

  def delete_patchinfo project
    visit patchinfo_show_path(package: 'patchinfo', project: project)
    find(:id, 'delete-patchinfo').click
    find(:id, 'del_dialog').must_have_text 'Delete Confirmation'
    find_button("Ok").click

    assert_equal page.current_path, project_show_path(project)
    find('#flash-messages').must_have_text "'patchinfo' was removed successfully from project"

    # FIXME: There must be a better way to test this
    begin
      Package.get_by_project_and_name(project.to_param, "patchinfo")
      assert false
    rescue Package::UnknownObjectError => e
      assert_equal "home:Iggy/patchinfo", e.message
    end
  end

  def test_create_patchinfo_and_edit_it
    login_Iggy
    visit project_show_path(project: "home:Iggy")
    open_new_patchinfo
    create_patchinfo_for_test(
      :summary => "This is a test for the patchinfoeditor",
      :description => LONG_DESCRIPTION,
      :category => "optional",
      :rating => "critical")

    #edit the summary of the created patchinfo
    click_link("Edit patchinfo")
    create_patchinfo_for_test(
      :summary => "New summary for the patchinfo",
      :description => find(:id, "description").text,
      :category => find_field('category').find('option[selected]').text,
      :rating => find_field('rating').find('option[selected]').text)

    # now add an issue
    click_link("Edit patchinfo")
    create_patchinfo_for_test(
      :summary => find(:id, "summary").text,
      :description => find(:id, "description").text,
      :category => find_field('category').find('option[selected]').text,
      :rating => find_field('rating').find('option[selected]').text,
      :issue => "bnc#700500")
    delete_patchinfo('home:Iggy')
  end


  def test_create_patchinfo_with_issues
    login_Iggy
    visit project_show_path(project: "home:Iggy")
    open_new_patchinfo
    create_patchinfo_for_test(
      :summary => "This is a test for the patchinfoeditor",
      :description => LONG_DESCRIPTION,
      :category => "optional",
      :rating => "critical",
      :issue => "bnc#770555,bnc#700500")

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
    find_link("bnc#700501")
    issues = "123456,bnc#700501".gsub(/\s+/, "").split(",")
    find_link(issues.last)
    click_button("Save Patchinfo")

    delete_patchinfo('home:Iggy')
  end
end
