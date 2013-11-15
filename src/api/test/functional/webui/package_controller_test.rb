# -*- coding: utf-8 -*-
require 'test_helper'

class Webui::PackageControllerTest < Webui::IntegrationTest

  include Webui::WebuiHelper

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
    login_user('fred', 'geröllheimer', to:
        webui_engine.package_binaries_path(package: 'TestPack', project: 'home:Iggy', repository: '10.2'))

    find(:link, 'Show').click
    page.must_have_text 'Maximal used disk space: 1005 Mbyte'
    page.must_have_text 'Maximal used memory: 288 Mbyte'
    page.must_have_text 'Total build: 503 s'
  end

  test 'delete package as user' do
    use_js

    login_user('fred', 'geröllheimer')
    delete_and_recreate_kdelibs
  end

  test 'delete package as admin' do
    use_js

    login_king
    delete_and_recreate_kdelibs
  end

  test 'Iggy adds himself as reviewer' do
    use_js

    login_Iggy to: webui_engine.package_users_path(package: 'TestPack', project: 'home:Iggy')
    check('user_reviewer_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath('.//input[@id="user_reviewer_Iggy"][@disabled="disabled"]')
    click_link 'Advanced'
    click_link 'Meta'
    page.must_have_text '<person userid="Iggy" role="reviewer"/>'
  end

  test 'Iggy removes himself as bugowner' do
    use_js

    login_Iggy to: webui_engine.package_meta_path(package: 'TestPack', project: 'home:Iggy')
    page.must_have_text '<person userid="Iggy" role="bugowner"/>'
    within '#package_tabs' do
      click_link('Users')
    end
    uncheck('user_bugowner_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath './/input[@id="user_bugowner_Iggy"][@disabled="disabled"]'
    click_link 'Advanced'
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
    use_js
    login_Iggy
    visit webui_engine.root_path + '/package/show/home:Iggy/TestPack'
    fill_comment
  end

  test 'another succesful comment creation' do
    use_js
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
    use_js
    login_Iggy 
    visit webui_engine.root_path + '/package/show/BaseDistro3/pack2'

    find(:id, 'reply_link_id_201').click
    fill_in 'reply_body_201', with: 'Comment Body'
    find(:id, 'add_reply_201').click
    find('#flash-messages').must_have_text 'Comment added successfully '
  end

  test 'diff is empty' do
    visit '/package/rdiff/BaseDistro2.0/pack2.linked?opackage=pack2&oproject=BaseDistro2.0'
    find('#content').must_have_text 'No source changes!'
  end

  test 'revision is empty' do
    visit '/package/rdiff/BaseDistro2.0/pack2.linked?opackage=pack2&oproject=BaseDistro2.0&rev='
    flash_message_type.must_equal :alert
    flash_message.must_equal 'Error getting diff: revision is empty'
  end

  test 'group can modify' do
    use_js

    # verify we do not test ghosts
    login_adrian to: webui_engine.package_users_path(package: 'TestPack', project: 'home:Iggy')

    page.wont_have_link 'Add group'
    logout

    login_Iggy to: webui_engine.package_users_path(package: 'TestPack', project: 'home:Iggy')
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
    login_adrian to: webui_engine.package_users_path(package: 'TestPack', project: 'home:Iggy')
    page.must_have_link 'Add group'
  end

  test 'derived packages' do
    use_js

    login_adrian to: webui_engine.package_show_path(package: 'pack2', project: 'BaseDistro')
    page.must_have_text '1 derived packages'
    click_link 'derived packages'

    page.must_have_text 'Derived Packages'
    page.must_have_link 'BaseDistro:Update'
  end

  test 'download logfile' do
    use_js

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

  test 'delete request' do
    use_js

    login_tom to: webui_engine.package_show_path(package: 'TestPack', project: 'home:Iggy')
    click_link 'Request deletion'

    fill_in 'description', with: 'It was just a test'
    click_button 'Ok'

    page.must_have_text 'Delete package home:Iggy / TestPack'
    click_button 'Revoke request'
  end

  uses_transaction :test_submit_package

  test 'submit package' do
    use_js

    login_adrian to: webui_engine.project_show_path(project: 'home:adrian')
    click_link 'Branch existing package'
    fill_in 'linked_project', with: 'home:dmayr'
    fill_in 'linked_package', with: 'x11vnc'
    click_button 'Create Branch'

    page.must_have_link 'Submit package'
    page.wont_have_link 'link diff'

    click_link 'Submit package'

    page.must_have_field('targetproject', with: 'home:dmayr')
    page.wont_have_field('targetpackage') # we do not offer renames (yet)

    page.wont_have_field('supersede')
    check('sourceupdate')

    click_button 'Ok'
    page.wont_have_selector '.dialog' # wait for the reload

    flash_message.must_match %r{Created submit request \d* to home:dmayr}
    requestid = flash_message.gsub(%r{Created submit request (\d*) to home:dmayr}, '\1').to_i
    within '#flash-messages' do
      click_link 'submit request'
    end

    logout
    login_dmayr to: webui_engine.request_show_path(id: requestid)
    page.must_have_text 'Submit package home:adrian / x11vnc (revision 1) to package home:dmayr / x11vnc'
    fill_in 'reason', with: 'You did not changed anything'
    click_button 'Decline request' # dmayr is a mean bastard
    logout

    login_adrian to: webui_engine.package_show_path(project: 'home:adrian', package: 'x11vnc')
    # now change something
    open_file 'README'
    page.must_have_text 'just to delete'
    edit_file 'My new cool text'

    click_link 'Overview'

    click_link 'link diff'

    page.must_have_text 'Difference Between Revision 2 and home:dmayr / x11vnc'

    click_link 'Submit to home:dmayr / x11vnc'

    page.must_have_field('targetproject', with: 'home:dmayr')
    page.must_have_field('targetpackage', with: 'x11vnc')

    # TODO: actually it does not make sense to display requests that we can't supersede
    # but that's for later
    within '#supersede_display' do
      page.must_have_text "#{requestid} by adrian"
    end

    check('supersede')
    click_button 'Ok'
    page.wont_have_selector '.dialog' # wait for the reload

    flash_message.must_match %r{Created submit request .* to home:dmayr}
    new_requestid = flash_message.gsub(%r{Created submit request (\d*) to home:dmayr}, '\1').to_i
    visit webui_engine.request_show_path(id: requestid)
    page.must_have_text "Request #{requestid} (superseded)"
    page.must_have_content "Superseded by #{new_requestid}"

  end
end
