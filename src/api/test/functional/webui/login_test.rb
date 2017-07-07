# encoding: utf-8

require_relative '../../test_helper'

class Webui::LoginTest < Webui::IntegrationTest
  #
  def open_home
    find(:id, "link-to-user-home").click
    page.must_have_text "Edit your account"
  end

  def user_real_name
    t = find(:id, "home-realname")
    return t.text if t
    return ''
  end

  #
  def change_user_real_name(new_name)
    find(:id, 'save_dialog').click

    fill_in "realname", with: new_name
    find(:css, "form[action='#{user_save_path}'] input[name='commit']").click

    flash_message.must_equal "User data for user '#{current_user}' successfully updated."
    flash_message_type.must_equal :info
    user_real_name.must_equal new_name
  end

  def test_login_as_user # spec/features/webui/login_spec.rb
    use_js

    # Login via login page
    visit user_login_path
    fill_in "Username", with: "tom"
    fill_in "Password", with: "buildservice"
    click_button("Log In")

    assert_equal "tom", find('#link-to-user-home').text

    within("div#subheader") do
      click_link("Logout")
    end
    assert_not page.has_css?("a#link-to-user-home")

    # Login via widget, and different user
    click_link("Log In")
    within("div#login-form") do
      fill_in "Username", with: "king"
      fill_in "Password", with: "sunflower"
      click_button("Log In")
    end

    assert_equal "king", find('#link-to-user-home').text
  end

  def test_login_invalid_entry # spec/features/webui/login_spec.rb
    visit root_path
    click_link 'login-trigger'
    within('#login-form') do
      fill_in 'Username', with: 'dasdasd'
      fill_in 'Password', with: 'dasdasd'
      click_button 'Log In'
    end
    flash_message.must_equal "Authentication failed"
    flash_message_type.must_equal :alert
  end

  def test_change_real_name_for_user # spec/features/webui/users/user_home_page.rb
    use_js

    login_Iggy
    open_home
    change_user_real_name Faker::Name.name
  end

  def test_remove_user_real_name # spec/features/webui/users/user_home_page.rb
    use_js

    login_Iggy
    open_home
    change_user_real_name ""
  end

  def test_real_name_stays_changed # spec/features/webui/users/user_home_page.rb
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
