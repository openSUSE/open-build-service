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
    assert find(:id, 'delete-package')
  end

  test "delete package as user" do
    login_user("fred", "geröllheimer")
    delete_and_recreate_kdelibs
  end

  test "delete package as admin" do
    login_king
    delete_and_recreate_kdelibs
  end

end
