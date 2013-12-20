require_relative '../../test_helper'

class Webui::GroupControllerTest < Webui::IntegrationTest

  uses_transaction :test_edit_group

  test 'list all groups' do
    use_js

    login_king to: configuration_groups_path

    find(:id, 'group_table_wrapper').must_have_text 'Showing 1 to 2 of 2 entries'
    find(:id, 'test_group_b').click
    find(:id, 'content').must_have_text 'This group does not contain users'

    visit configuration_groups_path
    find(:id, 'test_group').click
    find(:id, 'group_members_table_wrapper').must_have_text 'Showing 1 to 1 of 1 entries'
    find(:link, 'adrian').click
    assert page.current_url.end_with? user_show_path(user: 'adrian')
  end

  test 'edit group' do
    use_js

    login_king to: configuration_groups_path
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

  test 'invalid group' do
    visit group_show_path('nogroup')
    flash_message.must_equal "Group 'nogroup' does not exist"
    flash_message_type.must_equal :alert
  end

  test 'input tokens group' do
    visit group_tokens_path(term: 'nosuch')
    page.status_code.must_equal 404

    visit group_tokens_path(q: 'nosuch')
    page.status_code.must_equal 200

    page.source.must_equal '[]'

    visit group_tokens_path(q: 'test')
    page.status_code.must_equal 200

    JSON.parse(page.source).must_equal [{'name' => 'test_group'}, {'name' => 'test_group_b'}]
  end

  test 'autocomplete group' do
    visit group_autocomplete_path(q: 'nosuch')
    page.status_code.must_equal 404

    visit group_autocomplete_path(term: 'nosuch')
    page.status_code.must_equal 200

    page.source.must_equal '[]'

    visit group_autocomplete_path(term: 'test')
    page.status_code.must_equal 200

    JSON.parse(page.source).must_equal %w(test_group test_group_b)
  end

end
