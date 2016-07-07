# encoding: utf-8
require_relative '../../test_helper'

class Webui::ProjectControllerTest < Webui::IntegrationTest
  uses_transaction :test_admin_can_delete_every_project
  uses_transaction :test_create_project_publish_disabled

  def test_save_distributions
    use_js
    login_tom
    visit "/project/add_repository_from_default_list/home:tom"
    check("OBS Base 2.0")
    page.must_have_text("Successfully added repository 'Base_repo'")
    visit project_repositories_path(project: 'home:tom')
    page.must_have_text('Repositories of home:tom')
    assert first('strong a', text: "Base_repo")
  end

  def test_change_project_info # spec/features/webui/projects_spec.rb
    login_king to: project_show_path(project: 'LocalProject')

    click_link 'Edit description'
    page.must_have_text 'Edit Project Information of'

    fill_in 'project_title', with: 'My Title hopefully got changed'
    fill_in 'project_description', with: 'New description. Not kidding.. Brand new!'
    click_button 'Update Project'

    find(:id, 'project_title').text.must_equal 'My Title hopefully got changed'
    find(:id, 'description-text').text.must_equal 'New description. Not kidding.. Brand new!'
  end

  def test_save_repository
    use_js
    login_tom

    visit "/project/repositories/home:tom"
    within("div.repository-container", text: "SourceprotectedProject_repo") do
      click_link 'Edit repository'
    end
    click_link("Add additional path to this repository")

    fill_in("target_project", with: "Apache")
    page.execute_script("$('#target_project').keydown();")
    find(".ui-menu-item").click
    find("select#target_repo").select("SUSE_Linux_10.1")
    click_button("Add path to repository SourceprotectedProject_repo")

    assert_equal "/repositories/home:tom", page.current_path
    # Basic repository related information
    page.must_have_text "BaseDistro3/BaseDistro3_repo Apache/SUSE_Linux_10.1"

    within("div.repository-container", text: "SourceprotectedProject_repo") do
      click_link 'Edit repository'
    end
    # The more detailed view
    within "form#update_target_form-SourceprotectedProject_repo" do
      page.must_have_text "Apache/SUSE_Linux_10.1"
    end

    # Verify the repo really has been added
    path_element = PathElement.where(
      repository: Repository.find_by_name("SourceprotectedProject_repo"),
      link:       Repository.find_by_name("SUSE_Linux_10.1")
    ).first

    assert path_element
    assert_equal 2, path_element.position
  end

  def test_project_show
    use_js
    visit project_show_path(project: 'Apache')
    page.must_have_selector '#project_title'

    within "table#packages_table_wrapper_table" do
      assert_equal "apache2", find(:xpath, '(.//td/a)[1]').text
      assert_equal "libapr-util1", find(:xpath, '(.//td/a)[2]').text
      assert_equal "Taskjuggler", find(:xpath, '(.//td/a)[3]').text
      assert_equal "Tidy", find(:xpath, '(.//td/a)[4]').text
    end

    visit '/project/show?project=My:Maintenance'
    page.must_have_selector '#project_title'
  end

  uses_transaction :test_project_show_inherited_packages
  def test_project_show_inherited_packages
    use_js
    visit project_show_path(project: 'BaseDistro:Update')
    page.must_have_selector '#project_title'
    click_link("Inherited Packages")
    within "table#ipackages_wrapper_table" do
      assert_equal "_product", find(:xpath, '(.//td/a)[1]').text
      assert_equal "_product:fixed-release", find(:xpath, '(.//td/a)[2]').text
      assert_equal "pack1", find(:xpath, '(.//td/a)[3]').text
      # "pack2" is filtered since it exists in :Update project
      assert_equal "Pack3", find(:xpath, '(.//td/a)[4]').text
      assert_equal "patchinfo", find(:xpath, '(.//td/a)[5]').text
    end
  end

  def test_project_show_remote_instances
    visit project_show_path(project: 'RemoteInstance')
    page.must_have_text "Links against the remote OBS instance at: http://localhost:3200"
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
    find(:id, 'create_subproject_link').click
  end

  def test_create_hidden_project
    use_js

    create_subproject

    fill_in 'project_name', with: 'hiddenstuff'
    find(:id, 'access_protection').click
    find_button('Create Project').click

    find(:id, 'advanced_tabs_trigger').click
    find(:link, 'Meta').click

    editor_lines = page.evaluate_script("editors[0].getValue()").lines.map(&:strip)
    assert_equal editor_lines[4], "<access>"
    assert_equal editor_lines[5], "<disable/>"
    assert_equal editor_lines[6], "</access>"

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
    find('#flash-messages').must_have_text "Project was successfully removed."
    # now the actual assertion :)
    assert page.current_url.end_with?(project_show_path(project: 'home:tom')),
           "#{page.current_url} does not end with #{project_show_path(project: 'home:tom')}"
  end

  def test_delete_project_with_local_devel_package_defintions
    skip("project deletion must work without force")
  end

  def test_delete_project_with_external_devel_package_defintions
    skip("project deletion must fail. we should offer a force option to ignore it and remove anyway.")
  end

  def test_admin_can_delete_every_project
    use_js

    login_king to: project_show_path(project: 'LocalProject')
    find(:id, 'delete-project').click
    click_button('Ok')

    flash_message.must_equal "Project was successfully removed."
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
    find(:link, 'create_subproject_link').click
    fill_in 'project_name', with: 'hasrepotoremove'
    find_button('Create Project').click
    find(:link, 'Repositories').click
    find(:link, 'Add repositories').click
    find(:id, 'repo_images').click # aka "KIWI image build" checkbox
    page.must_have_text('Successfully added image repository')

    visit project_repositories_path(project: 'home:adrian:hasrepotoremove')
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
    find(:id, 'description-text').text.must_equal "I don't like the repo"
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
    page.must_have_text('Successfully added image repository')

    visit project_repositories_path(project: 'home:tom:addrepo')
    page.must_have_text('Repositories of home:tom:addrepo')
    assert first('strong a', text: "images")

    find(:link, 'Add repositories').click
    find(:link, 'Expert mode').click
    fill_autocomplete 'target_project', with: 'Base', select: 'BaseDistro'

    # wait for the ajax loader to disappear
    page.wont_have_selector 'input[disabled]'

    # wait for autoload of repos
    find('#target_repo').select('BaseDistro_repo')

    find_field('repo_name').value.must_equal 'BaseDistro_BaseDistro_repo'
    page.wont_have_selector '#add_repository_button[disabled]'
    # somehow the autocomplete logic creates a problem - and click_button refuses to click
    page.execute_script "$('#add_repository_button').click();"
    find(:id, 'flash-messages').must_have_text 'Successfully added repository'

    # add additional path to BaseDistro_BaseDistro_repo
    within("div.repository-container", text: "BaseDistro_BaseDistro_repo") do
      click_link 'Edit repository'
    end
    find(:link, 'Add additional path to this repository').click
    fill_autocomplete 'target_project', with: 'BaseDistro', select: 'BaseDistro:Update'
    page.wont_have_selector 'input[disabled]'
    find('#target_repo').select('BaseDistroUpdateProject_repo')
    page.wont_have_selector '#add_repository_button[disabled]'
    # somehow the autocomplete logic creates a problem - and click_button refuses to click
    page.execute_script "$('#add_repository_button').click();"
    find(:id, 'flash-messages').must_have_text 'Successfully added repository'

    # move BaseDistro:Update path down
    within("div.repository-container", text: "BaseDistro_BaseDistro_repo") do
      click_link 'Edit repository'
    end
    click_link 'move_path_up-BaseDistro:Update_BaseDistroUpdateProject_repo'
    find(:id, 'flash-messages').must_have_text 'Path moved up successfully'

    # move BaseDistro:Update path up again
    within("div.repository-container", text: "BaseDistro_BaseDistro_repo") do
      click_link 'Edit repository'
    end
    click_link 'move_path_down-BaseDistro:Update_BaseDistroUpdateProject_repo'
    find(:id, 'flash-messages').must_have_text 'Path moved down successfully'

    # disable arch_i586 for images repository
    within("div.repository-container", text: "images") do
      click_link 'Edit repository'
    end
    page.must_have_text 'Edit images' # popup opened
    uncheck('arch_i586')
    click_button 'Update images'

    # now check again
    page.must_have_text 'images (x86_64)'

    # check API too
    get '/source/home:tom:addrepo/_meta'
    assert_response :success
    assert_xml_tag :parent => { :tag => "repository", :attributes => { name: "images" } },
                   :tag => "arch", :content => "x86_64"
  end

  def test_save_meta
    use_js

    login_adrian
    visit(project_show_path(project: "home:adrian"))

    # Test reading meta data
    click_link("Advanced")
    click_link("Meta")
    # Note that textarea#editor_0 is a hidden element.
    # This isn't ideal for a test, but best we can do to test this part of the ui
    assert find(:css, "textarea#editor_0", visible: false).
      text(:all).include?("<title>adrian's Home Project</title>")

    # Test writing valid meta data
    xml = <<-XML.gsub(/(?:\s*\n|^\s*)/, '') # evaluate_script fails otherwise
<project name='home:adrian'>
  <title>My Home Project</title>
  <description/>
  <person userid='adrian' role='maintainer'/>
</project>
XML
    # Workaround. There doesn't seem to be a way to change stored meta content via the textarea.
    page.evaluate_script("editors[0].setValue(\"#{xml}\");")
    click_button("Save")
    find(:id, 'flash-messages').must_have_text("Config successfully saved!")
    click_link("Meta")
    meta_xml = find(:css, "textarea#editor_0", visible: false).text(:all)
    result = Nokogiri::XML(meta_xml)
    assert_select result, "project", name: "home:adrian" do
      assert_select "title", "My Home Project", 1
      assert_select "description", { count: 1, text: "" }, "Should have an empty description"
      assert_select "person", userid: "adrian", role: "maintainer"
    end
    assert_equal 3, result.xpath("/project/child::*").count, "Should not have additional nodes."

    # test writing invalid meta data
    xml = "<project name='home:adrian'> <title>My Home Project</title </project>"
    page.evaluate_script("editors[0].setValue(\"#{xml}\");")
    click_button("Save")
    find(:id, 'flash-messages').must_have_text("project validation error: expected '>'")

    xml = "<project name='home:adrian'><title>My Home Project</title></project>"
    page.evaluate_script("editors[0].setValue(\"#{xml}\");")
    click_button("Save")
    find(:id, 'flash-messages').
      must_have_text("project validation error: Expecting an element description, got nothing")

    # Trigger data reload and verify that nothing was saved
    click_link("Meta")
    meta_xml = find(:css, "textarea#editor_0", visible: false).text(:all)
    result = Nokogiri::XML(meta_xml)
    assert_select result, "project", name: "home:adrian" do
      assert_select "title", "My Home Project", 1
      assert_select "description", { count: 1, text: "" }, "Should have an empty description"
      assert_select "person", userid: "adrian", role: "maintainer"
    end
    assert_equal 3, result.xpath("/project/child::*").count, "Should not have additional nodes."
  end

  def test_save_meta_permission_check
    use_js

    login_adrian
    visit(project_show_path(project: "home:adrian"))

    # Test reading meta data
    click_link("Advanced")
    click_link("Meta")

    # Test writing valid meta data
    xml = <<-XML.gsub(/(?:\s*\n|^\s*)/, '') # evaluate_script fails otherwise
<project name='home:adrian'>
  <title>My Home Project</title>
  <description/>
  <remoteurl>http://remote.instance.org/</remoteurl>
  <person userid='adrian' role='maintainer'/>
</project>
XML
    # Workaround. There doesn't seem to be a way to change stored meta content via the textarea.
    page.evaluate_script("editors[0].setValue(\"#{xml}\");")
    click_button("Save")
    find(:id, 'flash-messages').must_have_text("Admin rights are required to change projects using remote resources")

    # not saved
    assert_nil Project.find_by_name("home:adrian").remoteurl

    # same with download url in repo
    visit(project_show_path(project: "home:adrian"))

    # Test reading meta data
    click_link("Advanced")
    click_link("Meta")

    # Test writing valid meta data
    xml = <<-XML.gsub(/(?:\s*\n|^\s*)/, '') # evaluate_script fails otherwise
<project name='home:adrian'>
  <title>My Home Project</title>
  <description/>
  <person userid='adrian' role='maintainer'/>
  <repository name='standard'>
    <download arch='x86_64' url='http://somewhere/' repotype='rpmmd'/>
  </repository>
</project>
XML
    # Workaround. There doesn't seem to be a way to change stored meta content via the textarea.
    page.evaluate_script("editors[0].setValue(\"#{xml}\");")
    click_button("Save")
    find(:id, 'flash-messages').must_have_text("Admin rights are required to change projects using remote resources")

    # not saved
    assert_nil Project.find_by_name("home:adrian").remoteurl
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
    SendEventEmails.new.perform
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      fill_in 'body', with: 'Comment Body'
      find_button('Add comment').click
      find('#flash-messages').must_have_text 'Comment was successfully created.'
      SendEventEmails.new.perform
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
    fill_autocomplete 'maintained_project', with: 'Apache', select: 'Apache'
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

  def test_create_home_project_for_user
    login_user('user1', 'buildservice')
    count = Project.count

    visit new_project_path

    fill_in 'project_name', with: 'home:user1'
    click_button('Create Project')

    assert_equal count + 1, Project.count

    assert Relationship.where(project: Project.find_by_name("home:user1"),
                              user: User.find_by_login("user1"),
                              role: Role.find_by_title("maintainer")).count > 0
  end

  def test_create_home_project_for_user_not_allowed
    login_user('user1', 'buildservice')
    count = Project.count

    # try to create it, but server config is not permitting it
    Configuration.stubs(:allow_user_to_create_home_project).returns(false)

    visit new_project_path
    fill_in 'project_name', with: 'home:user1'
    click_button('Create Project')

    assert_equal count, Project.count
    flash_message.must_equal "Sorry, you are not authorized to create this Project."
    flash_message_type.must_equal :alert
  end

  def test_create_global_project
    login_king to: new_project_path
    count = Project.count

    fill_in 'project_name', with: 'PublicProject'
    fill_in 'project_title', with: 'NewTitle'
    click_button('Create Project')

    assert_equal count + 1, Project.count
  end

  def test_create_global_project_as_user
    login_Iggy to: new_project_path
    count = Project.count

    fill_in 'project_name', with: 'PublicProject1'
    fill_in 'project_title', with: 'NewTitle'
    click_button('Create Project')

    assert_equal count, Project.count
    flash_message.must_equal "Sorry, you are not authorized to create this Project."
    flash_message_type.must_equal :alert
  end

  def test_breadcrumbs
    login_king to: new_project_path
    count = Project.count

    fill_in 'project_name', with: "my_project"
    fill_in 'project_title', with: 'none'
    click_button('Create Project')

    assert_equal count + 1, Project.count

    visit project_subprojects_path project: "my_project"
    click_link('create_subproject_link')

    fill_in :project_name, with: 'b'
    click_button('Create Project')

    # the parent project should be clickable
    within '#breadcrump' do
      find(:link, "my_project").text.must_equal "my_project"
    end
  end

  def test_breadcrumps_with_subproject_first
    login_king to: new_project_path
    count = Project.count

    fill_in 'project_name', with: "my_other_project:sub"
    click_button('Create Project')

    assert_equal count + 1, Project.count

    visit new_project_path
    fill_in :project_name, with: "my_other_project"
    click_button 'Create Project'

    assert_equal count + 2, Project.count

    visit project_show_path project: "my_other_project:sub"

    # the parent project should be clickable
    within '#breadcrump' do
      find(:link, "my_other_project").text.must_equal "my_other_project"
    end
  end

  def test_config_file
    use_js

    login_Iggy to: project_users_path(project: 'home:Iggy')
    click_link 'advanced_tabs_trigger'
    click_link 'Project Config'
    config_value = page.evaluate_script("editors[0].getValue()")
    assert_equal config_value, File.read("test/fixtures/files/home_iggy_project_config.txt").strip
  end

  def test_updating_config_file
    use_js

    project_config = File.read("test/fixtures/files/home_iggy_project_config.txt")
    new_project_config = File.read("test/fixtures/files/new_home_iggy_project_config.txt")

    login_Iggy to: project_users_path(project: 'home:Iggy')
    click_link 'advanced_tabs_trigger'
    click_link 'Project Config'
    page.execute_script("editors[0].setValue(\"#{new_project_config.gsub("\n", '\n')}\")")
    click_button 'Save'

    visit project_show_path project: "home:Iggy"
    click_link 'advanced_tabs_trigger'
    click_link 'Project Config'
    config_value = page.evaluate_script("editors[0].getValue()")
    assert_equal config_value, new_project_config

    # Leave the backend file as it was
    put '/source/home:Iggy/_config?' + {
        project: 'home:Iggy',
        comment: 'Updated by test'
      }.to_query, project_config
    assert_response :success
  end
end
