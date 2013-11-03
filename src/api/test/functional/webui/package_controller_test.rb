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
    visit webui_engine.root_path + '/package/show/home:Iggy/TestPack'
    fill_comment
  end

  test 'another succesful comment creation' do
    login_Iggy
    visit webui_engine.root_path + '/package/show?project=home:Iggy&package=TestPack'
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
    visit webui_engine.root_path + '/package/show/BaseDistro3/pack2'
    find(:id, 'reply_link_id_201').click
    fill_in 'reply_body_201', with: 'Comment Body'
    find(:id, 'add_reply_201').click
    find('#flash-messages').must_have_text 'Comment added successfully '
  end

  test 'diff is empty' do
    visit webui_engine.root_path + '/package/rdiff/BaseDistro2.0/pack2.linked?opackage=pack2&oproject=BaseDistro2.0'
    find('#content').must_have_text 'No source changes!'
  end

  test 'revision is mepty' do
    visit webui_engine.root_path + '/package/rdiff/BaseDistro2.0/pack2.linked?opackage=pack2&oproject=BaseDistro2.0&rev='
    flash_message_type.must_equal :alert
    flash_message.must_equal 'Error getting diff: revision is empty'
  end

  test "group can modify" do
    login_adrian
    # verify we do not test ghosts
    visit webui_engine.package_users_path(package: 'TestPack', project: 'home:Iggy')
    page.wont_have_link 'Add group'
    logout

    login_Iggy
    visit webui_engine.package_users_path(package: 'TestPack', project: 'home:Iggy')
    click_link 'Add group'
    page.must_have_text 'Add New Group to TestPack'
    fill_in 'groupid', with: 'test_group'
    click_button 'Add group'
    flash_message.must_equal 'Added group test_group with role maintainer'
    within('#group_table_wrapper') do
      page.must_have_link 'test_group'
    end
    logout

    # now test adrian can modify it for real
    login_adrian
    visit webui_engine.package_users_path(package: 'TestPack', project: 'home:Iggy')
    page.must_have_link 'Add group'
  end

  test "derived packages" do
    login_adrian
    visit webui_engine.package_show_path(package: 'pack2', project: 'BaseDistro')
    page.must_have_text '1 derived packages'
    click_link 'derived packages'

    page.must_have_text 'Derived Packages'
    page.must_have_link 'BaseDistro:Update'
  end

  test "download logfile" do
    visit webui_engine.package_show_path(package: 'TestPack', project: 'home:Iggy')
    # test reload and wait for the build to finish
    starttime=Time.now
    while Time.now - starttime < 10
      first('.icons-reload').click
      if page.has_selector? '.buildstatus'
        break if find('.buildstatus').text == 'succeeded'
      end
    end
    find('.buildstatus').must_have_text 'succeeded'
    click_link 'succeeded'
    find(:id, 'log_space').must_have_text '[1] this is my dummy logfile -> ümlaut'
    first(:link, 'Download logfile').click
    # don't bother with the ümlaut
    assert_match %r{this is my dummy}, page.source
  end
end
