require_relative '../../test_helper'

class Webui::GroupControllerTest < Webui::IntegrationTest
  uses_transaction :test_edit_group

  def test_list_all_groups # spec/features/webui/groups_spec.rb
    use_js

    login_king to: groups_path

    find(:id, 'group-table_wrapper').must_have_text 'Showing 1 to 5 of 5 entries'
    find(:id, 'test_group_empty').click
    find(:id, 'content').must_have_text 'This group does not contain users'

    visit groups_path
    find(:id, 'test_group').click
    find(:id, 'group-members-table_wrapper').must_have_text 'Showing 1 to 2 of 2 entries'
    find(:link, 'adrian').click
    assert page.current_url.end_with? user_show_path(user: 'adrian')
  end

  def test_edit_group # spec/features/webui/groups_spec.rb
    use_js

    login_king to: groups_path
    within '#group-test_group' do
      find('td.users').text.must_equal 'adrian_downloader, adrian'
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

  def test_invalid_group # spec/controllers/webui/groups_controller_spec.rb
    visit group_show_path('nogroup')
    flash_message.must_equal "Group 'nogroup' does not exist"
    flash_message_type.must_equal :alert
  end

  def test_input_tokens_group # spec/controllers/webui/groups_controller_spec.rb
    visit group_tokens_path(term: 'nosuch')
    page.status_code.must_equal 404

    visit group_tokens_path(q: 'nosuch')
    page.status_code.must_equal 200

    page.source.must_equal '[]'

    visit group_tokens_path(q: 'test')
    page.status_code.must_equal 200

    JSON.parse(page.source).must_equal [{ 'name' => 'test_group' },
                                        { 'name' => 'test_group_b' },
                                        { 'name' => 'test_group_empty' }]
  end

  def test_autocomplete_group # spec/controllers/webui/groups_controller_spec.rb
    visit group_autocomplete_path(q: 'nosuch')
    page.status_code.must_equal 404

    visit group_autocomplete_path(term: 'nosuch')
    page.status_code.must_equal 200

    page.source.must_equal '[]'

    visit group_autocomplete_path(term: 'test')
    page.status_code.must_equal 200

    JSON.parse(page.source).must_equal %w(test_group test_group_b test_group_empty)
  end
end
