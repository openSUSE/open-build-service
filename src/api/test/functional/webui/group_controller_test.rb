require 'test_helper'

class Webui::GroupControllerTest < Webui::IntegrationTest

  test "list all groups" do
    login_king
    visit webui_engine.configuration_groups_path

    find(:id, 'group_table_wrapper').must_have_text "Showing 1 to 2 of 2 entries"
    find(:id, 'test_group_b').click
    find(:id, 'content').must_have_text "This group does not contain users"

    visit webui_engine.configuration_groups_path
    find(:id, 'test_group').click
    find(:id, 'group_members_table_wrapper').must_have_text "Showing 1 to 1 of 1 entries"
    find(:id, 'adrian').click
    assert page.current_url.end_with? webui_engine.home_path(user: 'adrian')
  end

end
