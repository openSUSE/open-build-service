require 'test_helper'

class Webui::ProjectControllerTest < Webui::IntegrationTest

  uses_transaction :test_admin_can_delete_every_project
  uses_transaction :test_create_project_publish_disabled

  test 'project show' do
    visit webui_engine.project_show_path(project: 'Apache')
    page.must_have_selector '#project_title'
    visit '/project/show?project=My:Maintenance'
    page.must_have_selector '#project_title'
  end

  test 'kde4 has two packages' do
    visit '/project/show?project=kde4'
    find('#packages_info').must_have_text 'Packages (2)'
    within('#packages_info') do
      page.must_have_link 'kdebase'
      page.must_have_link 'kdelibs'
    end
  end

  test 'adrian can edit kde4' do
    # adrian is maintainer via group on kde4
    login_adrian to: webui_engine.project_show_path(project: 'kde4')

    # really simple test to get started
    page.must_have_link 'delete-project'
    page.must_have_link 'edit-description'
  end

  def create_subproject
    login_tom to: webui_engine.project_subprojects_path(project: 'home:tom')
    find(:id, 'link-create-subproject').click
  end

  test 'create project publish disabled' do
    create_subproject
    fill_in 'name', with: 'coolstuff'
    find(:id, 'disable_publishing').click
    find_button('Create Project').click
    find(:link, 'Repositories').click
    # publish disabled icon should appear
    page.must_have_selector 'div.icons-publish_disabled_blue'
  end

  test 'create invalid ns' do
    login_tom to: webui_engine.project_new_path(ns: 'home:toM')
    flash_message.must_equal "Invalid namespace name 'home:toM'"
  end

  test 'create hidden project' do
    use_js

    create_subproject

    fill_in 'name', with: 'hiddenstuff'
    find(:id, 'access_protection').click
    find_button('Create Project').click

    find(:id, 'advanced_tabs_trigger').click
    find(:link, 'Meta').click

    # TODO: find a more reliable way to retrieve the text - having the line numbers in here sounds dangerous
    find(:css, 'div.CodeMirror-lines').must_have_text %r{<access> 6 <disable/> 7 </access>}

    # now check that adrian can't see it
    logout
    login_adrian to: webui_engine.project_subprojects_path(project: 'home:tom')

    page.wont_have_text 'hiddenstuff'
  end

  test 'delete subproject redirects to parent' do
    use_js

    create_subproject
    fill_in 'name', with: 'toberemoved'
    find_button('Create Project').click

    find(:id, 'delete-project').click
    find_button('Ok').click
    find('#flash-messages').must_have_text "Project 'home:tom:toberemoved' was removed successfully"
    # now the actual assertion :)
    assert page.current_url.end_with?(webui_engine.project_show_path(project: 'home:tom')), "#{page.current_url} does not end with #{webui_engine.project_show_path(project: 'home:tom')}"
  end

  test 'delete home project' do
    use_js

    login_user('user1', '123456', to: webui_engine.project_show_path(project: 'home:user1'))

    # now on to a suprise - the project needs to be created on first login
    find_button('Create Project').click

    find(:id, 'delete-project').click
    find_button('Ok').click

    find('#flash-messages').must_have_text "Project 'home:user1' was removed successfully"
    # now the actual assertion :)
    assert page.current_url.end_with? webui_engine.project_list_public_path
  end

  test 'admin can delete every project' do
    use_js

    login_king to: webui_engine.project_show_path(project: 'LocalProject')
    find(:id, 'delete-project').click
    find_button('Ok').click

    flash_message.must_equal "Project 'LocalProject' was removed successfully"
    assert page.current_url.end_with? webui_engine.project_list_public_path
    find('#project_list').wont_have_text 'LocalProject'

    # now that it worked out we better make sure to recreate it.
    # The API database is rolled back on test end, but the backend is not
    visit webui_engine.project_new_path
    fill_in 'name', with: 'LocalProject'
    find_button('Create Project').click
  end

  test 'request project repository target removal' do
    use_js

    # Let user1 create a project with a repo that others can request to delete
    login_adrian to: webui_engine.project_show_path(project: 'home:adrian')
    find(:link, 'Subprojects').click
    find(:link, 'Create subproject').click
    fill_in 'name', with: 'hasrepotoremove'
    find_button('Create Project').click
    find(:link, 'Repositories').click
    find(:link, 'Add repositories').click
    find(:id, 'repo_images').click # aka "KIWI image build" checkbox
    find_button('Add selected repositories').click
    page.must_have_link('Delete repository')
    logout

    # check that anonymous has no links
    visit webui_engine.project_show_path(project: 'home:adrian:hasrepotoremove')
    page.wont_have_link('Request repository deletion')
    page.wont_have_link('Remove repository')

    # Now let tom create the repository delete request:
    login_tom to: webui_engine.project_show_path(project: 'home:adrian:hasrepotoremove')
    find(:link, 'Repositories').click
    find(:link, 'Request repository deletion').click
    # Wait for the dialog to appear
    find(:css, '.dialog h2').must_have_text 'Create Repository Delete Request'
    fill_in 'description', with: "I don't like the repo"
    find_button('Ok').click
    find(:css, 'span.ui-icon.ui-icon-info').must_have_text 'Created repository delete request'
    logout

    # Finally, user1 should accept the request and make sure the repo is gone
    login_adrian to: webui_engine.project_show_path(project: 'home:adrian:hasrepotoremove')
    find('#tab-requests a').click # The project tab "Requests"
    find('.request_link').click # Should be the first and only request for this project
    find(:id, 'description_text').text.must_equal "I don't like the repo"
    fill_in 'reason', with: 'really? ok'
    find(:id, 'accept_request_button').click
    visit webui_engine.project_show_path(project: 'home:adrian:hasrepotoremove')
    find(:link, 'Repositories').click
    page.wont_have_selector '#images' # The repo "images" should be gone by now
  end

  test 'add repo' do
    use_js

    visit webui_engine.project_repositories_path(project: 'home:Iggy')
    # just check anonymous has no links
    page.wont_have_link 'Edit Repository'
    page.wont_have_link 'Delete Repository'

    create_subproject
    fill_in 'name', with: 'addrepo'
    find_button('Create Project').click
    find('#tab-repositories a').click
    find(:link, 'Add repositories').click
    find(:id, 'repo_images').click # aka "KIWI image build" checkbox
    find_button('Add selected repositories').click
    assert first(:id, 'images')

    find(:link, 'Add repositories').click
    find(:link, 'advanced interface').click
    fill_autocomplete 'target_project', with: 'Local', select: 'LocalProject'

    # wait for the ajax loader to disappear
    page.wont_have_selector 'input[disabled]'

    # wait for autoload of repos
    find('#target_repo').select('pop')

    find_field('repo_name').value.must_equal 'LocalProject_pop'
    page.wont_have_selector '#add_repository_button[disabled]'
    # somehow the autocomplete logic creates a problem - and click_button refuses to click
    page.execute_script "$('#add_repository_button').click();"
    find(:id, 'flash-messages').must_have_text 'Build targets were added successfully'
  end

  test 'list all' do
    use_js

    visit webui_engine.project_list_public_path
    first(:css, 'p.main-project a').click
    # verify it's a project
    assert page.current_url.end_with? webui_engine.project_show_path(project: 'BaseDistro')

    visit webui_engine.project_list_public_path
    # avoid random results once projects moves to page 2
    find(:id, 'projects_table_length').select('100')
    find(:id, 'project_list').must_have_link 'BaseDistro'
    find(:id, 'project_list').wont_have_link 'HiddenProject'
    find(:id, 'project_list').wont_have_link 'home:adrian'
    uncheck('excludefilter')
    find(:id, 'project_list').must_have_link 'home:adrian'

    login_king to: webui_engine.project_list_public_path
    find(:id, 'projects_table_length').select('100')
    find(:id, 'project_list').must_have_link 'HiddenProject'
  end

  test 'Iggy adds himself as reviewer' do
    use_js
    login_Iggy to: webui_engine.project_users_path(project: 'home:Iggy')
    check('user_reviewer_Iggy')
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath('.//input[@id="user_reviewer_Iggy"][@disabled="disabled"]')
    click_link('advanced_tabs_trigger')
    click_link 'Meta'
    page.must_have_text '<person userid="Iggy" role="reviewer"/>'
  end

  test 'Iggy removes homer as maintainer' do
    login_Iggy to: webui_engine.project_users_path(project: 'home:Iggy')
    uncheck 'user_maintainer_hidden_homer'
    # wait for it to be clickable again before switching pages
    page.wont_have_xpath('.//input[@id="user_maintainer_hidden_homer"][@disabled="disabled"]')
    click_link 'advanced_tabs_trigger'
    click_link 'Meta'
    page.wont_have_text '<person userid="homer" role="maintainer"/>'
  end

  test 'check status' do
    visit webui_engine.project_status_path(project: 'LocalProject')
    page.must_have_text 'Include version updates' # just don't crash
  end

  test 'succesful comment creation' do
    use_js

    login_Iggy to: '/project/show/home:Iggy'
    fill_in 'title', with: 'Comment Title'
    fill_in 'body', with: 'Comment Body'
    find_button('Add comment').click
    find('#flash-messages').must_have_text 'Comment added successfully '
  end

  test 'another succesful comment creation' do
    login_Iggy to: '/project/show?project=home:Iggy'
    fill_in 'title', with: 'Comment Title'
    fill_in 'body', with: 'Comment Body'
    find_button('Add comment').click
    find('#flash-messages').must_have_text 'Comment added successfully '
  end

  test 'succesful reply comment creation' do
    use_js
    login_Iggy to: '/project/show/BaseDistro'
    find(:id, 'reply_link_id_100').click
    fill_in 'reply_body_100', with: 'Comment Body'
    find(:id, 'add_reply_100').click
    find('#flash-messages').must_have_text 'Comment added successfully '
  end

  test 'removing architectures in repo works' do
    use_js
    login_Iggy to: webui_engine.project_repositories_path(project: 'home:Iggy')

    page.must_have_text '10.2 (i586, x86_64)'
    click_link 'Edit repository'
    page.must_have_text 'Edit 10.2' # popup opened
    uncheck('arch_i586')
    click_button 'Update 10.2'

    # wait for the button to be disabled again before continue
    page.must_have_xpath('.//input[@id="save_button"][@disabled="disabled"]')

    # now check again
    visit webui_engine.project_repositories_path(project: 'home:Iggy')
    page.must_have_text '10.2 (x86_64)'

    # verify _meta
    visit webui_engine.project_meta_path(project: 'home:Iggy')
    page.wont_have_text '<arch>i586</arch>'
  end

  test 'buildresults' do
    use_js

    visit webui_engine.project_show_path(project: 'home:Iggy')
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
    visit webui_engine.project_show_path(project: 'home:Iggy')
    click_link '10.2'
    page.must_have_text 'There are no cycles in this repository.'
  end

  test 'repository links' do
    visit webui_engine.project_repositories_path(project: 'home:Iggy')
    all(:link, '10.2').each do |l|
      l['href'].must_equal webui_engine.project_repository_state_path(project: 'home:Iggy', repository: '10.2')
    end
  end
end
