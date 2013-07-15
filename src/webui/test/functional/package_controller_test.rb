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
    first(:id, 'user_reviewer_Iggy').click
    click_link "Meta"
    page.must_have_text '<person userid="Iggy" role="reviewer"/>'
  end
end
