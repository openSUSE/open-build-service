# encoding: utf-8

require_relative '../../test_helper'
require 'faker'

class Webui::LoginTest < Webui::IntegrationTest
  #
  def open_home
    find(:id, "link-to-user-home").click
    page.must_have_text "Edit your account"
  end

  def user_real_name
    t = find(:id, "home-realname")
    if t
      return t.text
    else
      return ''
    end
  end

  #
  def change_user_real_name new_name
    find(:id, 'save_dialog').click

    fill_in "realname", with: new_name
    find(:css, "form[action='#{user_save_path}'] input[name='commit']").click

    flash_message.must_equal "User data for user '#{current_user}' successfully updated."
    flash_message_type.must_equal :info
    user_real_name.must_equal new_name
  end

  def test_login_as_user
    # pretty useless actually :)
    login_Iggy
    logout
  end

  def test_login_as_second_user
    login_tom
    logout
  end

  def test_login_invalid_entry
    visit root_path
    click_link 'login-trigger'
    within('#login-form') do
      fill_in 'Username', with: 'dasdasd'
      fill_in 'Password', with: 'dasdasd'
      click_button 'Log In'
    end
    flash_message.must_equal "Authentication failed"
    flash_message_type.must_equal :alert

    login_Iggy
    logout
  end

  def test_login_empty_entry
    visit root_path
    click_link 'login-trigger'
    within('#login-form') do
      fill_in 'Username', with: ''
      fill_in 'Password', with: ''
      click_button 'Log In'
    end
    flash_message.must_equal "Authentication failed"
    flash_message_type.must_equal :alert
  end

  def test_change_real_name_for_user
    use_js

    login_Iggy
    open_home
    change_user_real_name Faker::Name.name
  end

  def test_remove_user_real_name
    use_js

    login_Iggy
    open_home
    change_user_real_name ""
  end

  def test_real_name_stays_changed
    use_js

    login_Iggy
    open_home
    new_name = "New imaginary name " + Time.now.to_i.to_s
    change_user_real_name new_name
    logout
    login_Iggy
    open_home
    user_real_name.must_equal new_name
  end
end
