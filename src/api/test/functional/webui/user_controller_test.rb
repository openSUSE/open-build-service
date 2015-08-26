require_relative '../../test_helper'

class Webui::UserControllerTest < Webui::IntegrationTest

  def test_edit
    login_king to: user_edit_path(user: 'tom')

    fill_in 'realname', with: 'Tom Thunder'
    click_button 'Update'

    find('#flash-messages').must_have_text("User data for user 'tom' successfully updated.")
  end

  def test_show_user_page
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

  def test_show_icons
    visit '/user/icon/Iggy.png'
    page.status_code.must_equal 200
    visit '/user/icon/Iggy.png?size=20'
    page.status_code.must_equal 200
    visit '/user/show/Iggy'
    page.status_code.must_equal 200
    visit '/user/show/Iggy?size=20'
    page.status_code.must_equal 200
  end

  def test_notification_settings_for_group
    login_adrian to: user_notifications_path

    page.must_have_text 'Get mails if in group'
    page.must_have_checked_field('test_group')
    uncheck('test_group')
    click_button 'Update'
    flash_message.must_equal 'Notifications settings updated'
    page.must_have_text 'Get mails if in group'
    page.must_have_unchecked_field('test_group')
  end

  def test_notification_settings_without_group
    login_tom to: user_notifications_path

    page.wont_have_text 'Get mails if in group'
    click_button 'Update'
    # we still get a
    flash_message.must_equal 'Notifications settings updated'
  end

  def test_notification_settings_for_events
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

  def test_that_redirect_after_login_works
    visit search_path
    visit user_login_path
    fill_in 'Username', with: "tom"
    fill_in 'Password', with: "thunder"
    click_button 'Log In'

    assert_equal "tom", User.current.try(:login)
    assert_equal search_path, current_path
  end
end
