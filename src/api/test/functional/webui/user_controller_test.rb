require_relative '../../test_helper'

class Webui::UserControllerTest < Webui::IntegrationTest
  def test_edit # spec/controllers/webui/user_controller_spec.rb
    login_king to: user_edit_path(user: 'tom')

    fill_in 'realname', with: 'Tom Thunder'
    click_button 'Update'

    find('#flash-messages').must_have_text("User data for user 'tom' successfully updated.")
  end

  def test_creation_of_home_projects # spec/features/webui/users/users_home_project_spec.rb, spec/models/user_spec.rb
    User.current = users(:user4)
    login_user "user4", "buildservice"

    page.must_have_text "user4 | Create Home | Logout"
    click_link("Create Home")
    assert_equal "home:user4", find("#project_name").value
    click_button("Create Project")

    page.must_have_text "user4 | Home Project | Logout"
    assert Project.where(name: User.current.home_project_name).exists?
  end

  def test_show_user_page #  spec/controllers/webui/user_controller_spec.rb
    # email hidden to public
    visit user_show_path(user: 'tom')
    page.must_have_text 'Home of tom'
    page.wont_have_text 'tschmidt@example.com'

    # but visible to users
    login_adrian to: user_show_path(user: 'tom')
    page.must_have_text 'Home of tom'
    page.must_have_text 'tschmidt@example.com'

    # deleted accounts are not shown to users
    login_adrian to: user_show_path(user: 'deleted')
    find('#flash-messages').must_have_text("User not found deleted")

    # but admins
    login_king to: user_show_path(user: 'deleted')
    page.must_have_text 'Home of deleted'

    # invalid accounts do not crash
    login_adrian to: user_show_path(user: 'INVALID')
    find('#flash-messages').must_have_text("User not found INVALID")

    login_king to: user_show_path(user: 'INVALID')
    find('#flash-messages').must_have_text("User not found INVALID")
  end

  def test_show_user_tables # spec/models/users_spec.rb
    use_js
    visit user_show_path(user: 'fred')

    within "table#ipackages_wrapper_table" do
      assert_equal "TestPack", find(:xpath, './/tr[1]/td[1]').text
      assert_equal "home:Iggy", find(:xpath, './/tr[1]/td[2]').text

      assert_equal "ToBeDeletedTestPack", find(:xpath, './/tr[2]/td[1]').text
      assert_equal "home:Iggy", find(:xpath, './/tr[2]/td[2]').text
    end

    click_link("Involved Projects")

    within "table#projects_table" do
      assert_equal "Apache", find(:xpath, './/tr[1]/td[1]').text
      assert_equal "Up-to-date Apache packages", find(:xpath, './/tr[1]/td[2]').text

      assert_equal "home:fred", find(:xpath, './/tr[2]/td[1]').text
      assert_equal "can be used for operations, to be cleaned up afterwards", find(:xpath, './/tr[2]/td[2]').text

      assert_equal "home:fred:DeleteProject", find(:xpath, './/tr[3]/td[1]').text
      assert_equal "This project gets deleted by request test", find(:xpath, './/tr[3]/td[2]').text

      assert_equal "kde4", find(:xpath, './/tr[4]/td[1]').text
      assert_equal "blub", find(:xpath, './/tr[4]/td[2]').text
    end

    click_link("Owned Project/Packages")

    within "table#iowned_wrapper_table" do
      assert_equal "Apache", find(:xpath, './/tr[1]/td[2]').text

      assert_equal "apache2", find(:xpath, './/tr[2]/td[1]').text
      assert_equal "Apache", find(:xpath, './/tr[2]/td[2]').text
    end
  end

  def test_index # spec/controllers/webui/users_spec.rb
    login_tom
    visit users_path
    flash_message_type.must_equal :alert
    flash_message.must_equal "Requires admin privileges"
    assert_equal root_path, page.current_path

    login_king
    visit users_path
    assert_equal users_path, page.current_path
    page.must_have_text "Manage users."
  end

  def test_show_icons # spec/features/webui/users/users_icons_spec.rb
    visit '/user/icon/Iggy.png'
    page.status_code.must_equal 200
    visit '/user/icon/Iggy.png?size=20'
    page.status_code.must_equal 200
    visit '/user/show/Iggy'
    page.status_code.must_equal 200
    visit '/user/show/Iggy?size=20'
    page.status_code.must_equal 200
  end

  def test_notification_settings_for_group # spec/features/webui/users/users_notifications_settings_spec.rb
    login_adrian to: user_notifications_path

    page.must_have_text 'Get mails if in group'
    page.must_have_checked_field('test_group')
    uncheck('test_group')
    click_button 'Update'
    flash_message.must_equal 'Notifications settings updated'
    page.must_have_text 'Get mails if in group'
    page.must_have_unchecked_field('test_group')
  end

  def test_notification_settings_without_group # this test was dropped
    login_tom to: user_notifications_path

    page.wont_have_text 'Get mails if in group'
    click_button 'Update'
    # we still get a
    flash_message.must_equal 'Notifications settings updated'
  end

  def test_notification_settings_for_events # this test was dropped
    login_adrian to: user_notifications_path

    page.must_have_text 'Events to get email for'
    page.must_have_checked_field('Event::RequestStatechange_creator')
    uncheck('Event::RequestStatechange_creator')
    check('Event::CommentForPackage_maintainer')
    check('Event::CommentForPackage_commenter')
    check('Event::CommentForProject_maintainer')
    check('Event::CommentForProject_commenter')
    click_button 'Update'
    flash_message.must_equal 'Notifications settings updated'
    page.must_have_text 'Events to get email for'
    page.must_have_unchecked_field('Event::RequestStatechange_creator')
    page.must_have_checked_field('Event::CommentForPackage_maintainer')
    page.must_have_checked_field('Event::CommentForPackage_commenter')
    page.must_have_checked_field('Event::CommentForProject_maintainer')
    page.must_have_checked_field('Event::CommentForProject_commenter')
  end

  def test_that_require_login_works # spec/controllers/webui/users_spec.rb
    logout
    visit users_path
    assert_equal user_login_path, page.current_path
    flash_message.must_equal "Please login to access the requested page."
  end

  def test_that_require_admin_works # spec/controllers/webui/users_spec.rb
    login_tom
    visit users_path
    assert_equal root_path, page.current_path
    flash_message.must_equal "Requires admin privileges"
  end

  def test_that_redirect_after_login_works # spec/controllers/webui/users_spec.rb
    use_js

    visit search_path
    click_link("Log In")
    fill_in 'Username', with: "tom"
    fill_in 'Password', with: "buildservice"
    click_button 'Log In'

    assert_equal "tom", find('#link-to-user-home').text
    assert_equal search_path, current_path
  end

  def test_that_redirect_from_user_do_login_works
    use_js

    visit user_login_path
    fill_in 'Username', with: "tom"
    fill_in 'Password', with: "buildservice"
    click_button 'Log In'

    assert_equal "tom", find('#home-username').text
    assert_equal "/user/show/tom", page.current_path
  end

  def test_redirect_after_register_user_action_works # spec/controllers/webui/users_spec.rb
    visit user_register_user_path
    within ".sign-up" do
      fill_in "Username", with: "bob"
      fill_in "Email address", with: "bob@suse.de"
      fill_in "Enter a password", with: "linux123"
    end
    click_button "Sign Up"

    new_user = User.find_by(login: "bob")
    assert new_user, "Should create a new user account"
    assert_equal "bob", User.current.try(:login), "Should log the user in"
    assert_equal project_show_path(new_user.home_project_name), current_path,
                 "Should redirect properly"
  end

  def test_redirect_after_register_user_action_works_no_homes # spec/controllers/webui/users_spec.rb
    Configuration.stubs(:allow_user_to_create_home_project).returns(false)

    visit user_register_user_path
    within ".sign-up" do
      fill_in "Username", with: "bob"
      fill_in "Email address", with: "bob@suse.de"
      fill_in "Enter a password", with: "linux123"
    end
    click_button "Sign Up"

    assert User.find_by(login: "bob"), "Should create a new user account"
    assert !Project.where(name: User.current.home_project_name).exists?,
           "Should not create a home projec when Configuration option is disabled"
    assert_equal "bob", User.current.try(:login), "Should log the user in"
    assert_equal root_path, current_path, "Should redirect properly"
  end
end
