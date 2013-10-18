# -*- coding: utf-8 -*-
require 'test_helper'

class Webui::PackageControllerTest < Webui::IntegrationTest

  def delete_and_recreate_kdelibs
    delete_package 'kde4', 'kdelibs'

    # now we need to recreate it again to avoid teardown to leave a mess in backend/API
    find(:link, 'Create package').click
    fill_in 'name', with: 'kdelibs'
    fill_in 'title', with: 'blub' # see the fixtures!!
    find_button('Save changes').click
    page.must_have_selector '#delete-package'
  end

  test 'show package binary as user' do
    login_user('fred', 'geröllheimer')
    visit(webui_engine.package_binaries_path(package: 'TestPack', project: 'home:Iggy', repository: '10.2'))

    find(:link, 'Show').click
    page.must_have_text 'Maximal used disk space: 1005 Mbyte'
    page.must_have_text 'Maximal used memory: 288 Mbyte'
    page.must_have_text 'Total build: 503 s'
  end

  test 'delete package as user' do
    login_user('fred', 'geröllheimer')
    delete_and_recreate_kdelibs
  end

  test 'delete package as admin' do
    login_king
    delete_and_recreate_kdelibs
  end

  test 'Iggy adds himself as reviewer' do
    login_Iggy
    visit webui_engine.package_users_path(package: 'TestPack', project: 'home:Iggy')
    check('user_reviewer_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath('.//input[@id="user_reviewer_Iggy"][@disabled="disabled"]')
    click_link 'Meta'
    page.must_have_text '<person userid="Iggy" role="reviewer"/>'
  end

  test 'Iggy removes himself as bugowner' do
    login_Iggy
    visit webui_engine.package_meta_path(package: 'TestPack', project: 'home:Iggy')
    page.must_have_text '<person userid="Iggy" role="bugowner"/>'
    within '#package_tabs' do
     click_link('Users')
    end
    uncheck('user_bugowner_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath './/input[@id="user_bugowner_Iggy"][@disabled="disabled"]'
    click_link 'Meta'
    page.wont_have_text '<person userid="Iggy" role="bugowner"/>'
  end

  def fill_comment
    fill_in 'title', with: 'Comment Title'
    fill_in 'body', with: 'Comment Body'
    find_button('Add comment').click
    find('#flash-messages').must_have_text 'Comment added successfully '
  end

  test 'succesful comment creation' do
    login_Iggy
    visit '/webui2/package/show/home:Iggy/TestPack'
    fill_comment
  end

  test 'another succesful comment creation' do
    login_Iggy
    visit '/webui2/package/show?project=home:Iggy&package=TestPack'
    fill_comment
  end

# broken test: issue 408
# test "check comments on remote projects" do
#   login_Iggy
#   visit webui_engine.package_show_path(project: "UseRemoteInstanceIndirect", package: "patchinfo")
#   fill_comment
# end

  test 'succesful reply comment creation' do
    login_Iggy
    visit '/webui2/package/show/BaseDistro3/pack2'
    find(:id,'reply_link_id_201').click
    fill_in 'reply_body_201', with: 'Comment Body'
    find(:id,'add_reply_201').click
    find('#flash-messages').must_have_text 'Comment added successfully '
   end

  test 'diff is empty' do
    visit '/webui2/package/rdiff/BaseDistro2.0/pack2.linked?opackage=pack2&oproject=BaseDistro2.0'
    find('#content').must_have_text 'No source changes!'
  end

  test 'revision is mepty' do
    visit '/webui2/package/rdiff/BaseDistro2.0/pack2.linked?opackage=pack2&oproject=BaseDistro2.0&rev='
    flash_message_type.must_equal :alert
    flash_message.must_equal 'revision is empty'
  end

end
