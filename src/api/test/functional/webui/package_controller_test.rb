# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::PackageControllerTest < Webui::IntegrationTest
  NEW_META_XML_FOR_TEST_PACK = '<package name="TestPack" project="home:Iggy">
  <title>My Test package Updated via Webui</title>
  <description/>
</package>'

  INVALID_META_XML_BECAUSE_PACKAGE_NAME = '<package name="TestPackOOO" project="home:Iggy">
  <title>Invalid meta PACKAGE NAME</title>
  <description/>
</package>'

  INVALID_META_XML_BECAUSE_PROJECT_NAME = '<package name="TestPack" project="home:IggyOOO">
  <title>Invalid meta PROJECT NAME</title>
  <description/>
</package>'

  INVALID_META_XML_BECAUSE_XML = '<package name="TestPack" project="home:Iggy">
  <title>Invalid meta WRONG XML</title>
  <description/>
</paaaaackage>'

  def delete_and_recreate_kdelibs
    delete_package 'kde4', 'kdelibs'

    # now we need to recreate it again to avoid teardown to leave a mess in backend/API
    find(:link, 'Create package').click
    fill_in 'name', with: 'kdelibs'
    fill_in 'title', with: 'blub' # see the fixtures!!
    find_button('Save changes').click
    page.must_have_selector '#delete-package'
  end

  def test_branch_package
    use_js
    login_Iggy

    visit package_show_path(project: "BaseDistro3", package: "pack2")
    click_link("Branch package")
    click_button("Ok")

    assert Project.where(name: "home:Iggy:branches:BaseDistro3").exists?
    assert_equal package_show_path(project: "home:Iggy:branches:BaseDistro3", package: "pack2"),
                 page.current_path

    # Branch from project with Update project configured
    visit package_show_path(project: "BaseDistro", package: "pack1")
    click_link("Branch package")
    click_button("Ok")
    assert_equal package_show_path(project: "home:Iggy:branches:BaseDistro:Update", package: "pack1"),
                 page.current_path,
                 "Should create project 'home:Iggy:branches:BaseDistro:Update' and redirect to that project"
  end

  def test_live_build_log_doesnt_cause_500_error
    visit(package_live_build_log_path(
            project: "home:tom",
            package: "nonexistant",
            repository: "BaseRepo",
            arch: "x86_64"
    ))

    assert_equal page.current_path, project_show_path("home:tom")
    page.must_have_text "Couldn't find package 'nonexistant' in project 'home:tom'. Are you sure it exists?"

    visit(package_live_build_log_path(
            project: "home:foo",
            package: "nonexistant",
            repository: "BaseRepo",
            arch: "x86_64"
    ))

    assert_equal page.current_path, root_path
    page.must_have_text "Couldn't find project 'home:foo'. Are you sure it still exists?"
  end

  def test_show_package_binary_as_user
    login_user('fred', 'buildservice', to:
        package_binaries_path(package: 'TestPack', project: 'home:Iggy', repository: '10.2'))

    find(:link, 'Show').click
    page.must_have_text 'Maximal used disk space: 1005 Mbyte'
    page.must_have_text 'Maximal used memory: 288 Mbyte'
    page.must_have_text 'Total build: 503 s'
  end

  def test_show_invalid_package
    visit package_show_path(package: 'TestPok', project: 'home:Iggy')
    page.status_code.must_equal 404
  end

  def test_show_invalid_project
    visit package_show_path(package: 'TestPok', project: 'home:Oggy')
    page.status_code.must_equal 404
  end

  uses_transaction :test_delete_package_as_user
  def test_delete_package_as_user
    use_js

    login_user('fred', 'buildservice')
    delete_and_recreate_kdelibs
  end

  uses_transaction :test_delete_package_as_admin
  def test_delete_package_as_admin
    use_js

    login_king
    delete_and_recreate_kdelibs
  end

  def test_delete_package_with_devel_defintion
    skip("delete must fail (without force option), no matter if the package is in local project or another one")
  end

  def test_Iggy_adds_himself_as_reviewer # spec/support/shared_examples/features/user_tab.rb
    use_js

    login_Iggy to: package_users_path(package: 'TestPack', project: 'home:Iggy')
    check('user_reviewer_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath('.//input[@id="user_reviewer_Iggy"][@disabled="disabled"]')
    click_link 'Advanced'
    click_link 'Meta'
    page.must_have_text '<person userid="Iggy" role="reviewer"/>'
  end

  def test_Iggy_removes_himself_as_bugowner # spec/support/shared_examples/features/user_tab.rb
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
    find('#flash-messages').must_have_text 'Comment was successfully created.'
  end

  def test_succesful_comment_creation
    use_js
    login_Iggy
    visit '/package/show/home:Iggy/TestPack'
    # rubocop:disable Metrics/LineLength
    fill_comment "Write some http://link.com\n\nand some other\n\n* Markdown\n* markup\n\nReferencing sr#23, bco#24, fate#25, @_nobody_, @a-dashed-user and @Iggy. https://anotherlink.com"
    # rubocop:enable Metrics/LineLength
    within('div.thread_level_0') do
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
      page.must_have_xpath '//a[@href="https://anotherlink.com"]'
    end
  end

  def test_another_succesful_comment_creation
    use_js
    login_Iggy
    visit '/package/show?project=home:Iggy&package=TestPack'
    # @Iggy works at the very beginning and requests are case insensitive
    fill_comment "@Iggy likes to mention himself and to write request#23 with capital 'R', like Request#23."
    within('div.thread_level_0') do
      page.must_have_xpath '//a[contains(@href, "/request/show/23") and text()="request#23"]'
      page.must_have_xpath '//a[contains(@href, "/request/show/23") and text()="Request#23"]'
      page.must_have_link '@Iggy'
    end
  end

  def test_check_comments_on_remote_projects
    login_Iggy
    visit package_show_path(project: 'UseRemoteInstanceIndirect', package: 'patchinfo')
    fill_comment
  end

  def test_succesful_reply_comment_creation
    use_js
    login_Iggy
    visit '/package/show/BaseDistro3/pack2'

    find(:id, 'reply_link_id_201').click
    fill_in 'reply_body_201', with: 'Comment Body'
    find(:id, 'add_reply_201').click
    find('#flash-messages').must_have_text 'Comment was successfully created.'
  end

  def test_diff_is_empty
    visit '/package/rdiff/BaseDistro2.0/pack2.linked?opackage=pack2&oproject=BaseDistro2.0'
    find('#content').must_have_text 'No source changes!'
  end

  def test_revision_is_empty
    visit '/package/rdiff/BaseDistro2.0/pack2.linked?opackage=pack2&oproject=BaseDistro2.0&rev='
    flash_message_type.must_equal :alert
    flash_message.must_equal 'Error getting diff: revision is empty'
  end

  def test_group_can_modify # spec/support/shared_examples/features/user_tab.rb
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

  def test_derived_packages
    use_js

    login_adrian to: package_show_path(package: 'pack2', project: 'BaseDistro')
    page.must_have_text '1 derived packages'
    click_link 'derived packages'

    page.must_have_text 'Derived Packages'
    page.must_have_link 'BaseDistro:Update'
  end

  def test_download_logfile
    use_js

    visit package_show_path(package: 'TestPack', project: 'home:Iggy')
    # test reload and wait for the build to finish
    find('.icons-reload').click
    first('.buildstatus').must_have_text 'succeeded'
    click_link 'succeeded'
    find(:id, 'log_space').must_have_text '[1] this is my dummy logfile -> ümlaut'
    first(:link, 'Download logfile').click
    # don't bother with the ümlaut
    assert_match %r{this is my dummy}, page.source
  end

  def test_delete_request
    use_js

    login_tom to: package_show_path(package: 'TestPack', project: 'home:Iggy')
    click_link 'Request deletion'

    fill_in 'description', with: 'It was just a test'
    click_button 'Ok'

    page.must_have_text 'Delete package home:Iggy / TestPack'
    click_button 'Revoke request'
  end

  def test_change_devel_request
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

  def test_submit_package
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
    page.wont_have_field('supersede_request_numbers[]')
    check('sourceupdate')
    click_button 'Ok'
    page.wont_have_selector '.dialog' # wait for the reload
    flash_message.must_match %r{Unable to submit, sources are unchanged}

    # modify and resubmit
    Suse::Backend.put( '/source/home:adrian/x11vnc/DUMMY?user=adrian', 'DUMMY')
    click_link 'Submit package'
    page.must_have_field('targetproject', with: 'home:dmayr')
    page.wont_have_field('supersede_request_numbers[]')
    check('sourceupdate')
    click_button 'Ok'

    # got a request
    page.wont_have_selector '.dialog' # wait for the reload
    flash_message.must_match %r{Created submit request \d* to home:dmayr}
    requestid = flash_message.gsub(%r{Created submit request (\d*) to home:dmayr}, '\1').to_i
    assert requestid
    assert requestid > 0
    within '#flash-messages' do
      click_link 'submit request'
    end

    logout
    login_dmayr to: request_show_path(number: requestid)
    page.must_have_text 'Submit package home:adrian / x11vnc (revision'
    page.must_have_text ' to package home:dmayr / x11vnc'
    fill_in 'reason', with: 'Bad idea'
    click_button 'Decline request' # dmayr is a mean bastard
    logout

    login_adrian to: package_show_path(project: 'home:adrian', package: 'x11vnc')
    # now change something more for a second request
    find(:css, "tr##{valid_xml_id('file-README')} td:first-child a").click
    page.must_have_text 'just to delete'
    # codemirror is not really test friendly, so just brute force it - we basically
    # want to test the load and save work flow not the codemirror library
    page.execute_script("editors[0].setValue('My new cool text');")
    assert !find(:css, '.buttons.save')['class'].split(' ').include?('inactive')
    find(:css, '.buttons.save').click
    page.must_have_selector('.buttons.save.inactive')
    click_link 'Overview'

    click_link 'link diff'

    page.must_have_text 'Difference Between Revision 3 and home:dmayr / x11vnc'

    click_link 'Submit to home:dmayr / x11vnc'

    page.must_have_field('targetproject', with: 'home:dmayr')
    page.must_have_field('targetpackage', with: 'x11vnc')

    within '#supersede_display' do
      page.must_have_text "#{requestid} by adrian"
    end

    page.must_have_field('supersede_request_numbers[]')
    all('input[name="supersede_request_numbers[]"]').each {|input| check(input[:id]) }
    click_button 'Ok'
    page.wont_have_selector '.dialog' # wait for the reload
    flash_message.must_match %r{Created submit request .* to home:dmayr}
    new_requestid = flash_message.gsub(%r{Created submit request (\d*) to home:dmayr}, '\1').to_i
    visit request_show_path(number: requestid)
    page.must_have_text "Request #{requestid} (superseded)"
    page.must_have_content "Superseded by #{new_requestid}"

    # You are not allowed to supersede requests you have no role in.
    #
    # TODO: actually it does not make sense to display requests that we can't supersede
    # but that's for later
    Suse::Backend.put( '/source/home:adrian/x11vnc/DUMMY2?user=adrian', 'DUMMY2')
    login_tom to: package_show_path(project: 'home:adrian', package: 'x11vnc')
    click_link 'Submit package'
    page.must_have_field('supersede_request_numbers[]')
    all('input[name="supersede_request_numbers[]"]').each {|input| check(input[:id]) }
    click_button 'Ok'
    page.wont_have_selector '.dialog' # wait for the reload
    flash_message.must_match %r{Created submit request \d* to home:dmayr}
    flash_message.must_match %r{Superseding failed: You have no role in request \d*}

    # You will not be given the option to supersede requests from other source projects
    login_tom to: project_show_path(project: 'home:tom')
    click_link 'Branch existing package'
    fill_in 'linked_project', with: 'home:dmayr'
    fill_in 'linked_package', with: 'x11vnc'
    click_button 'Create Branch'
    click_link 'Submit package'
    page.wont_have_field('supersede_request_numbers[]')
  end

  def test_submit_request_clientside_form_validation
    use_js
    login_Iggy

    visit(package_show_path(project: "home:Iggy", package: "TestPack"))
    click_link("Submit package")
    click_button("Ok")
    assert_equal package_show_path(project: "home:Iggy", package: "TestPack"),
                 page.current_path, "Client-side validation should have prevented package submission."

    fill_in "To target project", with: "nonexistant:project"
    click_button("Ok")
    assert_equal package_show_path(project: "home:Iggy", package: "TestPack"),
                 page.current_path, "Client-side validation should have prevented package submission."
  end

  def test_submit_request_unchanged_sources
    use_js
    login_Iggy

    visit(package_show_path(project: "home:Iggy", package: "TestPack"))
    click_link("Submit package")
    fill_in "To target project", with: "home:Iggy"
    click_button("Ok")
    page.must_have_text "Unable to submit, sources are unchanged"
    assert_equal package_show_path(project: "home:Iggy", package: "TestPack"),
                 page.current_path
  end

  def test_submit_request
    use_js
    login_Iggy

    visit(package_show_path(project: "home:Iggy", package: "TestPack"))
    click_link("Submit package")
    # Note: The whitespaces are part of the test, see issue#1248 for details
    fill_in "To target project", with: " home:Iggy "
    fill_in "To target package", with: " ToBeDeletedTestPack "
    click_button("Ok")
    page.must_have_text "Created submit request #{BsRequest.last.number} to home:Iggy"
    assert_equal package_show_path(project: "home:Iggy", package: "TestPack"),
                 page.current_path
  end

  def test_remove_file
    use_js

    login_dmayr to: package_show_path(project: 'home:dmayr', package: 'x11vnc')
    within 'tr#file-README' do
      find(:css, '.icons-page_white_delete').click
    end
    page.wont_have_link 'README'
    # restore now
    Suse::Backend.put( '/source/home:dmayr/x11vnc/README?user=king', 'just to delete')
  end

  def test_revisions
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

  def test_access_live_build_log
    use_js
    visit '/package/live_build_log/home:Iggy/TestPack/10.2/i586'
    page.status_code.must_equal 200
    page.must_have_text "Build finished"
    page.must_have_text "[1] this is my dummy logfile -> ümlaut"
    login_Iggy to: '/package/live_build_log/SourceprotectedProject/pack/repo/i586'
    page.status_code.must_equal 200
    flash_message.must_equal 'Could not access build log'
    visit '/package/live_build_log/UseRemoteInstance/pack2.linked/pop/i586/'
    page.status_code.must_equal 200
    page.must_have_text "Build finished"
    page.must_have_text "[1] this is my dummy logfile -> ümlaut"
  end

  def test_save_meta
    use_js

    skip("Valid test, but the rails stack on SLE 11 is currently not able to deal with
          nil vs. emtpy string differences in element content.")

    login_Iggy to: package_users_path(package: 'TestPack', project: 'home:Iggy')
    click_link("Advanced")
    click_link("Meta")
    original_meta_file = page.evaluate_script("editors[0].getValue()")

    page.evaluate_script("editors[0].setValue('#{NEW_META_XML_FOR_TEST_PACK.delete("\n")}');")
    click_button("Save")
    find('#flash-messages').must_have_text("The Meta file has been successfully saved.")
    click_link("Meta")
    meta_file = page.evaluate_script("editors[0].getValue()")
    assert_equal NEW_META_XML_FOR_TEST_PACK, meta_file.strip

    page.evaluate_script("editors[0].setValue('#{INVALID_META_XML_BECAUSE_PACKAGE_NAME.delete("\n")}');")
    click_button("Save")
    find('#flash-messages').must_have_text('package name in xml data does not match resource path component')
    click_link("Meta")
    meta_file = page.evaluate_script("editors[0].getValue()")
    assert_equal NEW_META_XML_FOR_TEST_PACK, meta_file.strip

    page.evaluate_script("editors[0].setValue('#{INVALID_META_XML_BECAUSE_PROJECT_NAME.delete("\n")}');")
    click_button("Save")
    find('#flash-messages').must_have_text("project name in xml data does not match resource path component")
    click_link("Meta")
    meta_file = page.evaluate_script("editors[0].getValue()")
    assert_equal NEW_META_XML_FOR_TEST_PACK, meta_file.strip

    page.evaluate_script("editors[0].setValue('#{INVALID_META_XML_BECAUSE_XML.delete("\n")}');")
    click_button("Save")
    find('#flash-messages').must_have_text('Opening and ending tag mismatch: package line 1 and paaaaackage.')
    click_link("Meta")
    meta_file = page.evaluate_script("editors[0].getValue()")
    assert_equal NEW_META_XML_FOR_TEST_PACK, meta_file.strip

    page.evaluate_script("editors[0].setValue('#{original_meta_file.delete("\n")}');")
    click_button("Save")
    find('#flash-messages').must_have_text("The Meta file has been successfully saved.")
  end

  def test_trigger_rebuild_via_binaries_view
    use_js
    login_king to: package_binaries_path(package: 'pack2.linked', project: 'BaseDistro2.0', repository: 'BaseDistro2_repo')

    page.all(:link, 'Trigger')[0].click
    find('#flash-messages').must_have_text('Triggered rebuild for BaseDistro2.0/pack2.linked successfully.')
  end

  def test_trigger_rebuild_via_live_log
    use_js
    login_king to: package_live_build_log_path(package: 'pack2.linked', project: 'BaseDistro2.0', repository: 'BaseDistro2_repo', arch: 'i586')
    find("div#content p:nth-of-type(3) > span.link_trigger_rebuild").click_link("Trigger Rebuild")
    find('#flash-messages').must_have_text('Triggered rebuild for BaseDistro2.0/pack2.linked successfully.')
  end
end
