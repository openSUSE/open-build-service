require 'test_helper'

class Webui::GroupControllerTest < Webui::IntegrationTest

  test 'list all groups' do
    use_js

    login_king to: webui_engine.configuration_groups_path

    find(:id, 'group_table_wrapper').must_have_text 'Showing 1 to 2 of 2 entries'
    find(:id, 'test_group_b').click
    find(:id, 'content').must_have_text 'This group does not contain users'

    visit webui_engine.configuration_groups_path
    find(:id, 'test_group').click
    find(:id, 'group_members_table_wrapper').must_have_text 'Showing 1 to 1 of 1 entries'
    find(:id, 'adrian').click
    assert page.current_url.end_with? webui_engine.home_path(user: 'adrian')
  end

  test 'edit group' do
    use_js

    login_king to: webui_engine.configuration_groups_path
    within '#group-test_group' do
      find('td.users').text.must_equal 'adrian'
      click_link 'Edit Group'
    end
    page.must_have_text 'Edit Group test_group'
    # testing autocomplete is horrible - see https://gist.github.com/jtanium/1229684
    page.find('input#members', visible: false).set 'user4'
    click_button 'Save'
    within '#group-test_group' do
      # adrian is out
      find('td.users').text.must_equal 'user4'
    end
  end

end
