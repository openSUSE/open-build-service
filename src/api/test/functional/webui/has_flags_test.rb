require_relative '../../test_helper'

class Webui::HasFlagsTest < Webui::IntegrationTest
  def test_project_flag_create # spec/features/webui/projects_spec.rb
    # FIXME: All of this is highly dependent on javascript execution.
    # Unhiding the flagtoggles, posting the link (unobstrusive javascript)
    # and replacing the buttons (unobstrusive javascript). Hence whenever
    # you run into resource constraints this will fail miserably on some
    # random point.
    skip('The interface in its current form is untestable...')

    use_js
    login_tom
    visit project_repositories_path(project: 'home:tom')
    # unhide all the stupid flag toggles...
    page.execute_script("$('.flagtoggle').removeClass('hidden')")

    find("#build_disable").click

    within('#build') do
      assert page.has_no_css?('.current_flag_state.icons-build_enable_grey'), 'found icons-build_enable_grey'
      assert page.has_css?('.current_flag_state.icons-build_disable_blue'), 'did not find icons-build_diable_blue'
    end
  end

  def test_project_flag_toggle # spec/features/webui/projects_spec.rb
    # FIXME: See above
    skip('The interface in its current form is untestable...')
    # @henne: No it isn't! ;-)

    use_js
    login_tom
    visit project_repositories_path(project: 'home:tom')
    # unhide all the stupid flag toggles...
    page.execute_script("$('.flagtoggle').removeClass('hidden')")

    find("#build_i586_disable").click
    within('#build_i586') do
      assert page.has_css?('.current_flag_state.icons-build_disable_blue')
    end

    find("#build_i586_enable").click
    within('#build_i586') do
      assert page.has_no_css?('.current_flag_state.icons-build_disable_blue'), 'found icons-build_disable_blue'
      assert page.has_no_css?('.current_flag_state.icons-build_enable_grey'), 'found icons-build_enable_grey'
      assert page.has_css?('.current_flag_state.icons-build_enable_blue'), 'did not find icons-build_enable_blue'
    end
  end

  def test_project_flag_remove # spec/features/webui/projects_spec.rb
    # FIXME: See above
    skip('The interface in its current form is untestable...')

    use_js
    login_tom
    visit project_repositories_path(project: 'home:tom')
    # unhide all the stupid flag toggles...
    page.execute_script("$('.flagtoggle').removeClass('hidden')")

    find("#build_x86_64_disable").click
    within('#build_x86_64') do
      assert page.has_no_css?('.current_flag_state.icons-build_enable_grey')
      assert page.has_css?('.current_flag_state.icons-build_disable_blue')
    end

    find("#build_x86_64_remove").click
    within('#build_x86_64') do
      assert page.has_no_css?('.current_flag_state.icons-build_disable_blue'), 'found icons-build_disable_blue'
      assert page.has_css?('.current_flag_state.icons-build_enable_grey'), 'did not find icons-build_enable_grey'
    end
  end

  def test_create_project_publish_disabled # spec/features/webui/projects_spec.rb
    login_tom to: project_subprojects_path(project: 'home:tom')
    find(:id, 'create_subproject_link').click
    fill_in 'project_name', with: 'coolstuff'
    page.check('disable_publishing')
    find_button('Create Project').click
    find(:link, 'Repositories').click
    # publish disabled icon should appear
    page.must_have_selector '.current_flag_state.icons-publish_disable_blue'
    assert_equal 'disable', Project.find_by(name: 'home:tom:coolstuff').flags.where(flag: 'publish').first.status

    # clean up
    Project.find_by(name: 'home:tom:coolstuff').flags.destroy_all
    assert_equal 0, Project.find_by(name: 'home:tom:coolstuff').flags.count
  end

  def test_project_repositories_uniq_archs # spec/features/webui/projects_spec.rb
    use_js
    login_tom

    visit project_repositories_path(project: 'home:tom')

    assert_equal 1, all(:xpath, "//table[@id='flag_table_build']/tbody/tr/th[text()='All']").count
    assert_equal 1, all(:xpath, "//table[@id='flag_table_publish']/tbody/tr/th[text()='All']").count
    assert_equal 1, all(:xpath, "//table[@id='flag_table_debuginfo']/tbody/tr/th[text()='All']").count
    assert_equal 1, all(:xpath, "//table[@id='flag_table_useforbuild']/tbody/tr/th[text()='All']").count

    assert_equal 1, all(:xpath, "//table[@id='flag_table_build']/tbody/tr/th[text()='i586']").count
    assert_equal 1, all(:xpath, "//table[@id='flag_table_publish']/tbody/tr/th[text()='i586']").count
    assert_equal 1, all(:xpath, "//table[@id='flag_table_debuginfo']/tbody/tr/th[text()='i586']").count
    assert_equal 1, all(:xpath, "//table[@id='flag_table_useforbuild']/tbody/tr/th[text()='i586']").count

    assert_equal 1, all(:xpath, "//table[@id='flag_table_build']/tbody/tr/th[text()='x86_64']").count
    assert_equal 1, all(:xpath, "//table[@id='flag_table_publish']/tbody/tr/th[text()='x86_64']").count
    assert_equal 1, all(:xpath, "//table[@id='flag_table_debuginfo']/tbody/tr/th[text()='x86_64']").count
    assert_equal 1, all(:xpath, "//table[@id='flag_table_useforbuild']/tbody/tr/th[text()='x86_64']").count
  end
end
