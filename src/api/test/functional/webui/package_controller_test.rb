# -*- coding: utf-8 -*-
require_relative '../../test_helper'

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
        package_binaries_path(package: 'TestPack', project: 'home:Iggy', repository: '10.2'))

    find(:link, 'Show').click
    page.must_have_text 'Maximal used disk space: 1005 Mbyte'
    page.must_have_text 'Maximal used memory: 288 Mbyte'
    page.must_have_text 'Total build: 503 s'
  end

  test 'show invalid package' do
    visit package_show_path(package: 'TestPok', project: 'home:Iggy')
    page.status_code.must_equal 404
    flash_message.must_equal 'Package "TestPok" not found in project "home:Iggy"'
  end

  test 'show invalid project' do
    visit package_show_path(package: 'TestPok', project: 'home:Oggy')
    page.status_code.must_equal 404
    flash_message.must_equal 'Project not found: home:Oggy'
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

    login_Iggy to: package_users_path(package: 'TestPack', project: 'home:Iggy')
    check('user_reviewer_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath('.//input[@id="user_reviewer_Iggy"][@disabled="disabled"]')
    click_link 'Advanced'
    click_link 'Meta'
    page.must_have_text '<person userid="Iggy" role="reviewer"/>'
  end

  test 'Iggy removes himself as bugowner' do
    use_js

    login_Iggy to: package_meta_path(package: 'TestPack', project: 'home:Iggy')
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

  def fill_comment(body = 'Comment Body')
    fill_in 'body', with: body
    find_button('Add comment').click
    find('#flash-messages').must_have_text 'Comment added successfully '
  end

  test 'succesful comment creation' do
    use_js
    login_Iggy
    visit root_path + '/package/show/home:Iggy/TestPack'
    fill_comment "Write some http://link.com\n\nand some other\n\n* Markdown\n* markup\n\nReferencing sr#23, bco#24, fate#25, @_nobody_, @a-dashed-user and @Iggy."
    within('div.comment_0') do
      page.must_have_link "http://link.com"
      page.must_have_xpath '//ul//li[text()="Markdown"]'
      page.must_have_xpath '//p[text()="and some other"]'
      page.must_have_xpath '//a[contains(@href, "/request/show/23") and text()="sr#23"]'
      page.must_have_xpath '//a[@href="http://bugzilla.clutter-project.org/show_bug.cgi?id=24" and text()="bco#24"]'
      page.must_have_xpath '//a[@href="https://features.opensuse.org/25" and text()="fate#25"]'
      page.must_have_link '@nobody'
      page.must_have_link '@a-dashed-user'
      page.must_have_link '@Iggy'
      page.must_have_xpath '//a[@href="http://link.com"]'
    end
  end

  test 'another succesful comment creation' do
    use_js
    login_Iggy 
    visit root_path + '/package/show?project=home:Iggy&package=TestPack'
    # @Iggy works at the very beginning and requests are case insensitive
    fill_comment "@Iggy likes to mention himself and to write request#23 with capital 'R', like Request#23."
    within('div.comment_0') do
      page.must_have_xpath '//a[contains(@href, "/request/show/23") and text()="request#23"]'
      page.must_have_xpath '//a[contains(@href, "/request/show/23") and text()="Request#23"]'
      page.must_have_link '@Iggy'
    end
  end

# broken test: issue 408
# test "check comments on remote projects" do
#   login_Iggy
#   visit package_show_path(project: "UseRemoteInstanceIndirect", package: "patchinfo")
#   fill_comment
# end

  test 'succesful reply comment creation' do
    use_js
    login_Iggy 
    visit root_path + '/package/show/BaseDistro3/pack2'

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
    login_adrian to: package_users_path(package: 'TestPack', project: 'home:Iggy')

    page.wont_have_link 'Add group'
    logout

    login_Iggy to: package_users_path(package: 'TestPack', project: 'home:Iggy')
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
    login_adrian to: package_users_path(package: 'TestPack', project: 'home:Iggy')
    page.must_have_link 'Add group'
  end

  test 'derived packages' do
    use_js

    login_adrian to: package_show_path(package: 'pack2', project: 'BaseDistro')
    page.must_have_text '1 derived packages'
    click_link 'derived packages'

    page.must_have_text 'Derived Packages'
    page.must_have_link 'BaseDistro:Update'
  end

  test 'download logfile' do
    use_js

    visit package_show_path(package: 'TestPack', project: 'home:Iggy')
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
    find(:id, 'log_space').must_have_text '[1] this is my dummy logfile -&gt; ümlaut'
    first(:link, 'Download logfile').click
    # don't bother with the ümlaut
    assert_match %r{this is my dummy}, page.source
  end

  test 'delete request' do
    use_js

    login_tom to: package_show_path(package: 'TestPack', project: 'home:Iggy')
    click_link 'Request deletion'

    fill_in 'description', with: 'It was just a test'
    click_button 'Ok'

    page.must_have_text 'Delete package home:Iggy / TestPack'
    click_button 'Revoke request'
  end

  test 'change devel request' do
    use_js

    # we need a package with current devel package
    login_tom to: package_show_path(package: 'kdelibs', project: 'kde4')
    click_link 'Request devel project change'

    page.must_have_content 'Do you want to request to change the devel project for package kde4 / kdelibs from project home:coolo:test'
    fill_in 'description', with: 'It was just a test'
    fill_in 'devel_project', with: 'home:coolo:test' # not really a change, but the package is reset
    click_button 'Ok'

    find('#flash-messages').must_have_text 'No such package: home:coolo:test/kdelibs'
    # check that no harm was done
    assert_equal packages(:home_coolo_test_kdelibs_DEVEL_package), packages(:kde4_kdelibs).develpackage
  end

  uses_transaction :test_submit_package

  test 'submit package' do
    use_js

    login_adrian to: project_show_path(project: 'home:adrian')
    click_link 'Branch existing package'
    fill_in 'linked_project', with: 'home:dmayr'
    fill_in 'linked_package', with: 'x11vnc'
    click_button 'Create Branch'

    page.must_have_link 'Submit package'
    page.wont_have_link 'link diff'

    # try to submit unchanged sources
    click_link 'Submit package'
    page.must_have_field('targetproject', with: 'home:dmayr')
    page.wont_have_field('supersede')
    check('sourceupdate')
    click_button 'Ok'
    page.wont_have_selector '.dialog' # wait for the reload
    flash_message.must_match %r{Unable to submit, sources are unchanged}

    # modify and resubmit
    Suse::Backend.put( '/source/home:adrian/x11vnc/DUMMY?user=adrian', 'DUMMY')
    click_link 'Submit package'
    page.must_have_field('targetproject', with: 'home:dmayr')
    page.wont_have_field('supersede')
    check('sourceupdate')
    click_button 'Ok'

    # got a request
    page.wont_have_selector '.dialog' # wait for the reload
    flash_message.must_match %r{Created submit request \d* to home:dmayr}
    requestid = flash_message.gsub(%r{Created submit request (\d*) to home:dmayr}, '\1').to_i
    within '#flash-messages' do
      click_link 'submit request'
    end

    logout
    login_dmayr to: request_show_path(id: requestid)
    page.must_have_text 'Submit package home:adrian / x11vnc (revision'
    page.must_have_text ' to package home:dmayr / x11vnc'
    fill_in 'reason', with: 'Bad idea'
    click_button 'Decline request' # dmayr is a mean bastard
    logout

    login_adrian to: package_show_path(project: 'home:adrian', package: 'x11vnc')
    # now change something more for a second request
    open_file 'README'
    page.must_have_text 'just to delete'
    edit_file 'My new cool text'

    click_link 'Overview'

    click_link 'link diff'

    page.must_have_text 'Difference Between Revision 3 and home:dmayr / x11vnc'

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
    visit request_show_path(id: requestid)
    page.must_have_text "Request #{requestid} (superseded)"
    page.must_have_content "Superseded by #{new_requestid}"
  end

  test 'supersede foreign request' do
    use_js

    login_adrian to: project_show_path(project: 'home:adrian')
    click_link 'Branch existing package'
    fill_in 'linked_project', with: 'Apache'
    fill_in 'linked_package', with: 'apache2'
    click_button 'Create Branch'

    page.must_have_link 'Submit package'
    page.wont_have_link 'link diff'

    # modify and resubmit
    Suse::Backend.put( '/source/home:adrian/apache2/DUMMY?user=adrian', 'DUMMY')
    click_link 'Submit package'
    page.must_have_field('targetproject', with: 'Apache')
    check('supersede')
    check('sourceupdate')
    click_button 'Ok'

    # got a request
    page.wont_have_selector '.dialog' # wait for the reload
    flash_message.must_match %r{Created submit request \d* to Apache}
    flash_message.must_match %r{Superseding failed: You have no role in request.*set state to superseded from a final state is not allowed}
  end

  test 'remove file' do
    use_js

    login_dmayr to: package_show_path(project: 'home:dmayr', package: 'x11vnc')
    within 'tr#file-README' do
      find(:css, '.icons-page_white_delete').click
    end
    page.wont_have_link 'README'
    # restore now
    Suse::Backend.put( '/source/home:dmayr/x11vnc/README?user=king', 'just to delete')
  end

  test "revisions" do
    visit package_view_revisions_path(project: 'BaseDistro2.0', package: 'pack2')
    click_link "Revisions"
    page.must_have_text "Revision Log of pack2 (3)"

    visit package_view_revisions_path(project: 'BaseDistro2.0', package: 'pack2', rev: '2')
    page.must_have_text "Revision Log of pack2 (2)"
    click_link "Show all"
    page.must_have_text "Revision Log of pack2 (3)"

    login_king
    20.times { |i| put '/source/BaseDistro2.0/pack2/dummy', i.to_s }
    visit package_view_revisions_path(project: 'BaseDistro2.0', package: 'pack2')
    page.must_have_text "Revision Log of pack2 (23)"
    all(:css, 'div.commit_item').count.must_equal 20
    click_link "Show all"
    all(:css, 'div.commit_item').count.must_equal 23
  end

  test 'access live build log' do
    visit '/package/live_build_log/home:Iggy/TestPack/10.2/i586'
    page.status_code.must_equal 200
    login_Iggy to: '/package/live_build_log/SourceprotectedProject/pack/repo/i586'
    page.status_code.must_equal 200
    flash_message.must_equal 'Could not access build log'
  end

  def test_revert_to_revision
    use_js
    login_king
    # create test package
    visit project_show_path(project: "BaseDistro2.0")
    click_link "Create package"
    fill_in 'name', with: 'tst_pack'
    click_button "Save changes"

    # add 6 new revision to source package
    6.times { |i| put '/source/BaseDistro2.0/tst_pack/rev_file_test', "revision #{(i + 1)}" }
    # check latest revision
    visit project_show_path(project: "BaseDistro2.0")
    click_link "tst_pack"
    click_link "rev_file_test"
    page.must_have_text "revision 6"

    # go to revision page and select second last revision (rev5)
    visit package_view_revisions_path(project: 'BaseDistro2.0', package: 'tst_pack', meta: '0')
    within('div#commit_item_5') do
      click_link "Files changed"
    end

    # create "revert to revision" submit request
    page.must_have_text "Changes of Revision 5"
    click_link "Revert BaseDistro2.0 / tst_pack to revision 5"

    # use same project, but set different target package name
    page.must_have_text "Create Submit Request"
    fill_in 'targetproject', with: 'BaseDistro2.0'
    fill_in 'targetpackage', with: 'tst_pack_rev5'
    fill_in 'description', with: 'testing revert to revision 5'
    click_button 'Ok'

    # check that request was submitted
    page.wont_have_selector '.dialog' # wait for the reload
    requestid = flash_message.gsub(%r{Created submit request (\d*) to BaseDistro2.0}, '\1').to_i

    # open request from project page and accept it
    visit project_show_path(project: "BaseDistro2.0")
    click_link "open request"
    find("a[href='/request/show/#{requestid}']").click
    page.must_have_text "testing revert to revision 5"
    page.must_have_text "Submit package BaseDistro2.0 / tst_pack (revision 5) to package BaseDistro2.0 / tst_pack_rev5"
    click_button "Accept request"

    # go to reverted package
    visit project_show_path(project: "BaseDistro2.0")
    click_link "tst_pack_rev5"
    page.must_have_text "testing revert to revision 5"

    # verify that correct revision was reverted
    click_link "rev_file_test"
    page.wont_have_text "revision 6" # from the latest revision
    page.must_have_text "revision 5" # from the reverted revision
  end
end
