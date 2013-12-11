require_relative '../../test_helper'

class Webui::UserControllerTest < Webui::IntegrationTest

  def test_edit
    login_king to: configuration_user_path(user: 'tom')

    fill_in 'realname', with: 'Tom Thunder'
    click_button 'Update'
    
    find('#flash-messages').must_have_text("User data for user 'tom' successfully updated.")
  end

  test 'notification settings for group' do
    login_adrian to: user_notifications_path

    page.must_have_text 'Get mails if in group'
    page.must_have_checked_field('test_group')
    uncheck('test_group')
    click_button 'Update'
    flash_message.must_equal 'Notifications settings updated'
    page.must_have_text 'Get mails if in group'
    page.must_have_unchecked_field('test_group')
  end

  test 'notification settings without group' do
    login_tom to: user_notifications_path

    page.wont_have_text 'Get mails if in group'
    click_button 'Update'
    # we still get a
    flash_message.must_equal 'Notifications settings updated'
  end

  test 'notification settings for events' do
    login_adrian to: user_notifications_path

    page.must_have_text 'Events to get email for'
    page.must_have_checked_field('request_statechange_creator')
    uncheck('request_statechange_creator')
    check('comment_for_package_maintainer')
    check('comment_for_package_creator')
    check('comment_for_project_maintainer')
    check('comment_for_project_reviewer')
    click_button 'Update'
    flash_message.must_equal 'Notifications settings updated'
    page.must_have_text 'Events to get email for'
    page.must_have_unchecked_field('request_statechange_creator')
    page.must_have_checked_field('comment_for_package_maintainer')
    page.must_have_checked_field('comment_for_package_creator')
    page.must_have_checked_field('comment_for_prxoject_maintainer')
    page.must_have_checked_field('comment_for_project_reviewer')
  end
end
