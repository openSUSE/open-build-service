require_relative '../../test_helper'

class Webui::ProjectControllerTest < Webui::IntegrationTest

  uses_transaction :test_admin_can_delete_every_project
  uses_transaction :test_create_project_publish_disabled

  def test_project_show
    visit project_show_path(project: 'Apache')
    page.must_have_selector '#project_title'
    visit '/project/show?project=My:Maintenance'
    page.must_have_selector '#project_title'
  end

  def test_kde4_has_two_packages
    use_js

    visit '/project/show?project=kde4'
    find('#packages').must_have_text 'Packages (2)'
    within('#raw_packages') do
      page.must_have_link 'kdebase'
      page.must_have_link 'kdelibs'
    end
  end

  def test_adrian_can_edit_kde4
    # adrian is maintainer via group on kde4
    login_adrian to: project_show_path(project: 'kde4')

    # really simple test to get started
    page.must_have_link 'delete-project'
    page.must_have_link 'edit-description'
  end

  def create_subproject
    login_tom to: project_subprojects_path(project: 'home:tom')
    find(:id, 'link-create-subproject').click
  end

  def test_create_project_publish_disabled
    create_subproject
    fill_in 'project_name', with: 'coolstuff'
    find(:id, 'disable_publishing').click
    find_button('Create Project').click
    find(:link, 'Repositories').click
    # publish disabled icon should appear
    page.must_have_selector 'div.icons-publish_disabled_blue'
  end

  def test_create_invalid_ns
    login_tom to: new_project_path(ns: 'home:toM')
    flash_message.must_equal "Invalid namespace name 'home:toM'"
  end

  def test_create_hidden_project
    use_js

    create_subproject

    fill_in 'project_name', with: 'hiddenstuff'
    find(:id, 'access_protection').click
    find_button('Create Project').click

    find(:id, 'advanced_tabs_trigger').click
    find(:link, 'Meta').click

    # TODO: find a more reliable way to retrieve the text - having the line numbers in here sounds dangerous
    find(:css, 'div.CodeMirror-lines').must_have_text %r{<access> 6 <disable/> 7 </access>}

    # now check that adrian can't see it
    logout
    login_adrian to: project_subprojects_path(project: 'home:tom')

    page.wont_have_text 'hiddenstuff'
  end

  def test_delete_subproject_redirects_to_parent
    use_js

    create_subproject
    fill_in 'project_name', with: 'toberemoved'
    find_button('Create Project').click

    find(:id, 'delete-project').click
    find_button('Ok').click
    find('#flash-messages').must_have_text "Project 'home:tom:toberemoved' was removed successfully"
    # now the actual assertion :)
    assert page.current_url.end_with?(project_show_path(project: 'home:tom')),
           "#{page.current_url} does not end with #{project_show_path(project: 'home:tom')}"
  end

  def test_delete_home_project
    use_js

    Project.find_by_name('home:user1').try(:destroy)

    login_user('user1', '123456', to: project_show_path(project: 'home:user1'))

    # now on to a suprise - the project needs to be created on first login
    find_button('Create Project').click

    find(:id, 'delete-project').click
    find_button('Ok').click

    find('#flash-messages').must_have_text "Project 'home:user1' was removed successfully"
    # now the actual assertion :)
    assert page.current_url.end_with? projects_path
  end

  def test_admin_can_delete_every_project
    use_js

    login_king to: project_show_path(project: 'LocalProject')
    find(:id, 'delete-project').click
    find_button('Ok').click

    flash_message.must_equal "Project 'LocalProject' was removed successfully"
    assert page.current_url.end_with? projects_path
    find('#project_list').wont_have_text 'LocalProject'

    # now that it worked out we better make sure to recreate it.
    # The API database is rolled back on test end, but the backend is not
    visit new_project_path
    fill_in 'project_name', with: 'LocalProject'
    find_button('Create Project').click
  end

  def test_request_project_repository_target_removal
    use_js

    # Let user1 create a project with a repo that others can request to delete
    login_adrian to: project_show_path(project: 'home:adrian')
    find(:link, 'Subprojects').click
    find(:link, 'Create subproject').click
    fill_in 'project_name', with: 'hasrepotoremove'
    find_button('Create Project').click
    find(:link, 'Repositories').click
    find(:link, 'Add repositories').click
    find(:id, 'repo_images').click # aka "KIWI image build" checkbox
    find_button('Add selected repositories').click
    page.must_have_link('Delete repository')
    logout

    # check that anonymous has no links
    visit project_show_path(project: 'home:adrian:hasrepotoremove')
    page.wont_have_link('Request repository deletion')
    page.wont_have_link('Remove repository')

    # Now let tom create the repository delete request:
    login_tom to: project_show_path(project: 'home:adrian:hasrepotoremove')
    find(:link, 'Repositories').click
    find(:link, 'Request repository deletion').click
    # Wait for the dialog to appear
    find(:css, '.dialog h2').must_have_text 'Create Repository Delete Request'
    fill_in 'description', with: "I don't like the repo"
    find_button('Ok').click
    find(:css, 'span.ui-icon.ui-icon-info').must_have_text 'Created repository delete request'
    logout

    # Finally, user1 should accept the request and make sure the repo is gone
    login_adrian to: project_show_path(project: 'home:adrian:hasrepotoremove')
    find('#tab-requests a').click # The project tab "Requests"
    find('.request_link').click # Should be the first and only request for this project
    find(:id, 'description_text').text.must_equal "I don't like the repo"
    fill_in 'reason', with: 'really? ok'
    find(:id, 'accept_request_button').click
    visit project_show_path(project: 'home:adrian:hasrepotoremove')
    find(:link, 'Repositories').click
    page.wont_have_selector '#images' # The repo "images" should be gone by now
  end

  uses_transaction :test_add_and_modify_repo
  def test_add_and_modify_repo
    use_js

    visit project_repositories_path(project: 'home:Iggy')
    # just check anonymous has no links
    page.wont_have_link 'Edit Repository'
    page.wont_have_link 'Delete Repository'

    create_subproject
    fill_in 'project_name', with: 'addrepo'
    find_button('Create Project').click
    find('#tab-repositories a').click
    find(:link, 'Add repositories').click
    find(:id, 'repo_images').click # aka "KIWI image build" checkbox
    find_button('Add selected repositories').click
    assert first(:id, 'images')

    find(:link, 'Add repositories').click
    find(:link, 'advanced interface').click
    fill_autocomplete 'target_project', with: 'Base', select: 'BaseDistro'

    # wait for the ajax loader to disappear
    page.wont_have_selector 'input[disabled]'

    # wait for autoload of repos
    find('#target_repo').select('BaseDistro_repo')

    find_field('repo_name').value.must_equal 'BaseDistro_BaseDistro_repo'
    page.wont_have_selector '#add_repository_button[disabled]'
    # somehow the autocomplete logic creates a problem - and click_button refuses to click
    page.execute_script "$('#add_repository_button').click();"
    find(:id, 'flash-messages').must_have_text 'Build targets were added successfully'

    # add additional path to BaseDistro_BaseDistro_repo
    click_link 'edit_repository_link_BaseDistro_BaseDistro_repo'
    find(:link, 'Add additional path to this repository').click
    fill_autocomplete 'target_project', with: 'BaseDistro', select: 'BaseDistro:Update'
    page.wont_have_selector 'input[disabled]'
    find('#target_repo').select('BaseDistroUpdateProject_repo')
    page.wont_have_selector '#add_path_to_repository_button[disabled]'
    # somehow the autocomplete logic creates a problem - and click_button refuses to click
    page.execute_script "$('#add_path_to_repository_button').click();"
    find(:id, 'flash-messages').must_have_text 'Path BaseDistro:Update/BaseDistroUpdateProject_repo added successfully'

    # move BaseDistro:Update path down
    click_link 'edit_repository_link_BaseDistro_BaseDistro_repo'
    click_link 'move_path_down-BaseDistro_Update_BaseDistroUpdateProject_repo'
    find(:id, 'flash-messages').must_have_text 'Path BaseDistro:Update/BaseDistroUpdateProject_repo moved successfully'

    # move BaseDistro:Update path up again
    click_link 'edit_repository_link_BaseDistro_BaseDistro_repo'
    click_link 'move_path_up-BaseDistro_Update_BaseDistroUpdateProject_repo'
    find(:id, 'flash-messages').must_have_text 'Path BaseDistro:Update/BaseDistroUpdateProject_repo moved successfully'

    # disable arch_i586 for images repository
    click_link 'edit_repository_link_images'
    page.must_have_text 'Edit images' # popup opened
    uncheck('arch_i586')
    click_button 'Update images'

    # wait for the button to be disabled again before continue
    page.must_have_xpath('.//input[@id="save_button-images"][@disabled="disabled"]')

    # now check again
    visit project_repositories_path(project: 'home:tom:addrepo')
    page.must_have_text 'images (x86_64)'

    # verify _meta
    visit project_meta_path(project: 'home:tom:addrepo')
    page.wont_have_text '<arch>i586</arch>'

    # check API too
    get '/source/home:tom:addrepo/_meta'
    assert_response :success
    assert_xml_tag :parent => { :tag => "repository", :attributes => { name: "images" } },
                   :tag => "arch", :content => "x86_64"
  end

  def test_list_all
    use_js

    visit project_list_public_path
    first(:css, 'p.main-project a').click
    # verify it's a project
    assert page.current_url.end_with? project_show_path(project: 'BaseDistro')

    visit project_list_public_path
    # avoid random results once projects moves to page 2
    find(:id, 'projects_table_length').select('100')
    find(:id, 'project_list').must_have_link 'BaseDistro'
    find(:id, 'project_list').wont_have_link 'HiddenProject'
    find(:id, 'project_list').wont_have_link 'home:adrian'

    click_link('Include home projects')
    find(:id, 'project_list').must_have_link 'home:adrian'

    login_king to: projects_path
    find(:id, 'projects_table_length').select('100')
    find(:id, 'project_list').must_have_link 'HiddenProject'
  end

  def test_Iggy_adds_himself_as_reviewer
    use_js
    login_Iggy to: project_users_path(project: 'home:Iggy')
    check('user_reviewer_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath('.//input[@id="user_reviewer_Iggy"][@disabled="disabled"]')
    click_link('advanced_tabs_trigger')
    click_link 'Meta'
    page.must_have_text '<person userid="Iggy" role="reviewer"/>'
  end

  def test_Iggy_removes_homer_as_maintainer
    login_Iggy to: project_users_path(project: 'home:Iggy')
    uncheck 'user_maintainer_hidden_homer'
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath('.//input[@id="user_maintainer_hidden_homer"][@disabled="disabled"]')
    click_link 'advanced_tabs_trigger'
    click_link 'Meta'
    page.wont_have_text '<person userid="homer" role="maintainer"/>'
  end

  def test_check_status
    visit project_status_path(project: 'LocalProject')
    page.must_have_text 'Include version updates' # just don't crash
  end

  def verify_email(fixture_name, email)
    should = load_fixture("event_mailer/#{fixture_name}").chomp
    lines = email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }
    lines.select! { |l| l !~ %r{^ boundary=} }
    lines.select! { |l| l !~ %r{^----==_mimepart} }
    assert_equal should, lines.join("\n")
  end

  def test_successful_comment_creation
    login_tom to: '/project/show/home:Iggy'
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      fill_in 'body', with: 'Comment Body'
      find_button('Add comment').click
      find('#flash-messages').must_have_text 'Comment was successfully created.'
    end
    email = ActionMailer::Base.deliveries.last
    verify_email('project_comment', email)
  end

  def test_unsuccessful_comment_creation
    login_tom to: '/project/show/home:Iggy'
    find_button('Add comment').click
    find('#flash-messages').must_have_text "Comment can't be saved: Body can't be blank."
  end

  def test_successful_reply_comment_creation
    use_js

    login_Iggy to: '/project/show/BaseDistro'
    find(:id, 'reply_link_id_100').click
    fill_in 'reply_body_100', with: 'Comment Body'
    find(:id, 'add_reply_100').click
    find('#flash-messages').must_have_text 'Comment was successfully created.'
  end

  def test_buildresults
    use_js

    visit project_show_path(project: 'home:Iggy')
    # test reload and wait for the build to finish
    starttime=Time.now
    while Time.now - starttime < 10
      page.must_have_selector '.icons-reload'
      first('.icons-reload').click
      if page.has_selector? '.repostatus'
        break if find('.repostatus').text =~ %r{succeeded: 1}
      end
    end
    click_link 'succeeded: 1'
    page.current_path.must_match %r{project/monitor}
    page.must_have_link 'TestPack'
    page.wont_have_link 'disabled'

    # this time we can assume repos are up
    visit project_show_path(project: 'home:Iggy')
    click_link '10.2'
    page.must_have_text 'There are no cycles for x86_64'
  end

  def test_repository_links
    visit project_repositories_path(project: 'home:Iggy')
    all(:link, '10.2').each do |l|
      l['href'].must_equal project_repository_state_path(project: 'home:Iggy', repository: '10.2')
    end
  end

  def test_request_deletion
    use_js

    login_tom to: project_show_path(project: 'home:Iggy')
    click_link 'Request deletion'

    fill_in 'description', with: 'It was just a test'
    click_button 'Ok'

    page.must_have_text 'Delete project home:Iggy'
    click_button 'Revoke request'
  end

  def test_add_maintenance_project
    use_js

    login_king to: project_show_path(project: 'My:Maintenance')
    click_link 'maintained projects'
    click_link 'Add project to maintenance'
    fill_autocomplete 'maintained_project', with: 'Apa', select: 'Apache'
    click_button 'Ok'
    page.must_have_link 'Apache'
  end

  def test_zypper_on_webui
    # people do strange things
    visit '/project/repository_state/Apache/content?repository=SLE11'
    flash_message.must_equal "Repository 'content' not found"
  end

  def test_do_not_cache_hidden
    use_js

    login_king to: projects_path
    # king can see HiddenProject
    page.must_have_link 'HiddenProject'

    logout

    # anoynmous should not see king's project list
    visit project_list_all_path
    page.must_have_link 'kde4'
    page.wont_have_link 'HiddenProject'

    login_adrian to: project_list_all_path
    # adrian is in test group, which is maintainer so he should see it too
    page.must_have_link 'HiddenProject'
  end

  def test_rebuild_time_on_apache
    login_tom to: project_rebuild_time_path(project: 'Apache', arch: 'i586', repository: 'SUSE_Linux_Factory')

    page.must_have_link 'Apache'
    # we only test it's not crashing here
    page.must_have_text 'Rebuildtime: '
  end
end
