require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class GroupControllerTest < ActionDispatch::IntegrationTest

  test "list all groups" do
    login_king
    visit configuration_groups_path

    find(:id, 'group_table_wrapper').must_have_text "Showing 1 to 2 of 2 entries"
    find(:id, 'test_group_b').click
    find(:id, 'content').must_have_text "This group does not contain users"

    visit configuration_groups_path
    find(:id, 'test_group').click
    find(:id, 'group_members_table_wrapper').must_have_text "Showing 1 to 1 of 1 entries"
    find(:id, 'adrian').click
    assert page.current_url.end_with? home_path(user: 'adrian')
  end

end
