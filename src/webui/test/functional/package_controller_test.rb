# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class PackageControllerTest < ActionDispatch::IntegrationTest

  def delete_and_recreate_kdelibs
    visit(package_show_path(package: 'kdelibs', project: 'kde4'))
    find(:id, 'delete-package').click
    assert find(:id, 'del_dialog').has_text? 'Delete Confirmation'
    find_button("Ok").click
    assert find('#flash-messages').has_text? "Package 'kdelibs' was removed successfully"

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
