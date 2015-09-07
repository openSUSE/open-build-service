# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::PatchinfoCreateTest < Webui::IntegrationTest

  setup do
    use_js
    @project = 'home:Iggy'
  end

  def test_create_patchinfo_with_too_short_summary
    login_Iggy
    visit project_show_path(project: "home:Iggy")

    click_link("Create patchinfo")
    page.must_have_text("Patchinfo-Editor for")
    fill_in "summary", with: "Too short"
    fill_in "description", with: "long text" * 20
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

    new_patchinfo[:zypp_restart_needed] ||= false
    new_patchinfo[:relogin] ||= false
    new_patchinfo[:reboot] ||= false
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

    if !new_patchinfo[:select_binaries].blank?
      for bin in new_patchinfo[:select_binaries]
        find('select#available_binaries').select(bin)
        click_button("add")
      end
    end

    find(:id, "zypp_restart_needed").click if new_patchinfo[:zypp_restart_needed]
    find(:id, "relogin").click if new_patchinfo[:relogin]
    find(:id, "reboot").click if new_patchinfo[:reboot]
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
      if !new_patchinfo[:select_binaries].blank?
        page.must_have_text "Selected binaries:"
        for bin in new_patchinfo[:select_binaries]
          page.must_have_text bin
        end
      end
      if new_patchinfo[:zypp_restart_needed]
        page.must_have_selector("#zypp_true")
      else
        page.must_have_selector("#zypp_false")
      end
      if new_patchinfo[:reboot]
        page.must_have_selector("#reboot_true")
      else
        page.must_have_selector("#reboot_false")
      end
      if new_patchinfo[:relogin]
        page.must_have_selector("#relogin_true")
      else
        page.must_have_selector("#relogin_false")
      end
    elsif new_patchinfo[:expect] == :no_permission
      flash_message.must_equal "No permission to edit the patchinfo-file."
      flash_message_type.must_equal :alert
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

  def test_create_patchinfo_with_desc_and_sum
    login_Iggy
    visit project_show_path(project: "home:Iggy")
    open_new_patchinfo
    create_patchinfo_for_test(
      :summary => "This is a test for the patchinfoeditor",
      :description => LONG_DESCRIPTION,
      :category => "recommended",
      :rating => "low")

    # check that the patchinfo is not editable for unauthorized users per buttons
    login_adrian(do_assert: false)
    visit patchinfo_show_path(project: "home:Iggy", package: "patchinfo")
    page.wont_have_content("Edit patchinfo")
    page.wont_have_content("Delete patchinfo")

    # check that the patchinfo is not editable per direct url for unauthorized users
    visit patchinfo_edit_patchinfo_path(project: "home:Iggy", package: "patchinfo")
    create_patchinfo_for_test(
      :summary => "This is a test for the patchinfoeditor",
      :description => LONG_DESCRIPTION,
      :category => "recommended",
      :rating => "low",
      :expect => :no_permission)

    # check that the patchinfo is not editable for anonymous user per buttons
    logout
    visit patchinfo_show_path(project: "home:Iggy", package: "patchinfo")
    page.wont_have_content("Edit patchinfo")
    page.wont_have_content("Delete patchinfo")

    # check that the patchinfo is not editable per direct url for unauthorized users
    visit patchinfo_edit_patchinfo_path(project: "home:Iggy", package: "patchinfo")
    page.must_have_text('Please Log In')

    login_Iggy
    delete_patchinfo('home:Iggy')
  end

  def test_create_patchinfo_with_desc_sum_changed_rating_and_category
    login_Iggy
    visit project_show_path(project: "home:Iggy")
    open_new_patchinfo
    create_patchinfo_for_test(
      :summary => "This is a test for the patchinfoeditor",
      :description => LONG_DESCRIPTION,
      :category => "optional",
      :rating => "critical")
    delete_patchinfo('home:Iggy')
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

  def test_create_patchinfo_with_flags
    login_Iggy
    visit project_show_path(project: "home:Iggy")
    open_new_patchinfo
    create_patchinfo_for_test(
      :summary => "This is a test for the patchinfo-editor",
      :description => LONG_DESCRIPTION,
      :category => "recommended",
      :rating => "low",
      :zypp_restart_needed => true,
      :relogin => true,
      :reboot => true,
      :expect => :success)
    delete_patchinfo('home:Iggy')
  end

  def test_create_patchinfo_with_binaries
    login_Iggy
    visit project_show_path(project: "home:Iggy")
    open_new_patchinfo
    create_patchinfo_for_test(
      :summary => "This is a test for the patchinfo-editor",
      :description => LONG_DESCRIPTION,
      :category => "recommended",
      :rating => "low",
      :select_binaries => %w(package delete_me),
      :expect => :success)
    click_link("Edit patchinfo")

    #remove 'delete_me' from selected binaries
    find('select#selected_binaries').select('delete_me')
    click_button("remove")
    click_button("Save Patchinfo")
    page.wont_have_text('delete_me')

    delete_patchinfo('home:Iggy')
  end

  # RUBY CODE ENDS HERE.
  # BELOW ARE APPENDED ALL DATA STRUCTURES USED BY THE TESTS.


# -------------------------------------------------------------------------------------- #
LONG_DESCRIPTION = <<LICENSE_END
        GNU GENERAL PUBLIC LICENSE
           Version 2, June 1991

 Copyright (C) 1989, 1991 Free Software Foundation, Inc.
 51 Franklin Steet, Fifth Floor, Boston, MA  02111-1307  USA
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

          Preamble

  The licenses for most software are designed to take away your
freedom to share and change it.  By contrast, the GNU General Public
License is intended to guarantee your freedom to share and change free
software--to make sure the software is free for all its users.  This
General Public License applies to most of the Free Software
Foundation's software and to any other program whose authors commit to
using it.  (Some other Free Software Foundation software is covered by
the GNU Library General Public License instead.)  You can apply it to
your programs, too.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
this service if you wish), that you receive source code or can get it
if you want it, that you can change the software or use pieces of it
in new free programs; and that you know you can do these things.

  To protect your rights, we need to make restrictions that forbid
anyone to deny you these rights or to ask you to surrender the rights.
These restrictions translate to certain responsibilities for you if you
distribute copies of the software, or if you modify it.

  For example, if you distribute copies of such a program, whether
gratis or for a fee, you must give the recipients all the rights that
you have.  You must make sure that they, too, receive or can get the
source code.  And you must show them these terms so they know their
rights.

  We protect your rights with two steps: (1) copyright the software, and
(2) offer you this license which gives you legal permission to copy,
distribute and/or modify the software.

  Also, for each author's protection and ours, we want to make certain
that everyone understands that there is no warranty for this free
software.  If the software is modified by someone else and passed on, we
want its recipients to know that what they have is not the original, so
that any problems introduced by others will not reflect on the original
authors' reputations.

  Finally, any free program is threatened constantly by software
patents.  We wish to avoid the danger that redistributors of a free
program will individually obtain patent licenses, in effect making the
program proprietary.  To prevent this, we have made it clear that any
patent must be licensed for everyone's free use or not licensed at all.

  The precise terms and conditions for copying, distribution and
modification follow.

        GNU GENERAL PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. This License applies to any program or other work which contains
a notice placed by the copyright holder saying it may be distributed
under the terms of this General Public License.  The "Program", below,
refers to any such program or work, and a "work based on the Program"
means either the Program or any derivative work under copyright law:
that is to say, a work containing the Program or a portion of it,
either verbatim or with modifications and/or translated into another
language.  (Hereinafter, translation is included without limitation in
the term "modification".)  Each licensee is addressed as "you".

Activities other than copying, distribution and modification are not
covered by this License; they are outside its scope.  The act of
running the Program is not restricted, and the output from the Program
is covered only if its contents constitute a work based on the
Program (independent of having been made by running the Program).
Whether that is true depends on what the Program does.

  1. You may copy and distribute verbatim copies of the Program's
source code as you receive it, in any medium, provided that you
conspicuously and appropriately publish on each copy an appropriate
copyright notice and disclaimer of warranty; keep intact all the
notices that refer to this License and to the absence of any warranty;
and give any other recipients of the Program a copy of this License
along with the Program.
LICENSE_END
# -------------------------------------------------------------------------------------- #


end
