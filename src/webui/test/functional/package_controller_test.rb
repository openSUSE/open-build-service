# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class PackageControllerTest < ActionDispatch::IntegrationTest

  def delete_and_recreate_kdelibs
    delete_package 'kde4', 'kdelibs'

    # now we need to recreate it again to avoid teardown to leave a mess in backend/API
    find(:link, "Create package").click
    fill_in "name", with: 'kdelibs'
    fill_in "title", with: "blub" # see the fixtures!!
    find_button("Save changes").click
    page.must_have_selector '#delete-package'
  end

  test "show package binary as user" do
    login_user("fred", "geröllheimer")
    visit(package_binaries_path(package: "TestPack", project: "home:Iggy", repository: "10.2"))

    find(:link, "Show").click
    page.must_have_text "Maximal used disk space: 1005 Mbyte"
    page.must_have_text "Maximal used memory: 288 Mbyte"
    page.must_have_text "Total build: 503 s"
  end

  test "delete package as user" do
    login_user("fred", "geröllheimer")
    delete_and_recreate_kdelibs
  end

  test "delete package as admin" do
    login_king
    delete_and_recreate_kdelibs
  end

  test "Iggy adds himself as reviewer" do
    login_Iggy
    visit package_users_path(package: "TestPack", project: "home:Iggy")
    check('user_reviewer_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath('.//input[@id="user_reviewer_Iggy"][@disabled="disabled"]')
    click_link "Meta"
    page.must_have_text '<person userid="Iggy" role="reviewer"/>'
  end

  test "Iggy removes himself as bugowner" do
    login_Iggy
    visit package_meta_path(package: "TestPack", project: "home:Iggy")
    page.must_have_text '<person userid="Iggy" role="bugowner"/>'
    within '#package_tabs' do
     click_link("Users")
    end
    uncheck('user_bugowner_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath './/input[@id="user_bugowner_Iggy"][@disabled="disabled"]'
    click_link "Meta"
    page.wont_have_text '<person userid="Iggy" role="bugowner"/>'
  end

  test "comment creation without login" do
    logout
    visit "/package/comments/home:Iggy/TestPack"
    find_button("Add comment").click
    find('#flash-messages').must_have_text "Please login to access the requested page."
  end

end
