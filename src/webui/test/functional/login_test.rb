# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"       
require 'faker'

class LoginTest < ActionDispatch::IntegrationTest
  
  #
  def open_home
    find(:css, "div#subheader a[href='/home']").click
  end

  def user_real_name
    t = first(:css, "div#content span#real-name")
    if t
      return t.text
    else
      return ''
    end
  end


  #
  def change_user_real_name new_name
    assert page.has_text? "Profile picture:"
    find(:css, "div#content a[href='/user/edit']").click

    fill_in "realname", with: new_name
    find(:css, "form[action='/user/save'] input[name='commit']").click

    assert_equal "User data for user '#{current_user}' successfully updated.", flash_message
    assert_equal :info, flash_message_type
    assert_equal new_name, user_real_name
  end


  test "login_as_user" do
    
    # pretty useless actually :)
    login_Iggy
    logout
  end

  test "login_as_second_user" do
  
    login_tom
    logout
  end

  test "login_invalid_entry" do
  
    visit "/"
    click_link 'login-trigger'
    within('#login-form') do
      fill_in 'Username', with: 'dasdasd'
      fill_in 'Password', with: 'dasdasd'
      click_button 'Login'
    end
    assert_equal "Authentication failed", flash_message
    assert_equal :alert, flash_message_type

    login_Iggy
    logout
  end

  
  test "login_empty_entry" do
  
    visit "/"
    click_link 'login-trigger'
    within('#login-form') do
      fill_in 'Username', with: ''
      fill_in 'Password', with: ''
      click_button 'Login'
    end
    assert_equal "Authentication failed", flash_message
    assert_equal :alert, flash_message_type
    
  end

  test "change_real_name_for_user" do
    login_Iggy
    open_home
    change_user_real_name Faker::Name.name
  end
  
  test "remove_user_real_name" do
    login_Iggy
    open_home
    change_user_real_name ""
  end

  
  test "real_name_stays_changed" do
    login_Iggy
    
    open_home
    new_name = "New imaginary name " + Time.now.to_i.to_s
    change_user_real_name new_name
    logout
    login_Iggy
    open_home
    assert_equal new_name, user_real_name
  end
  
end
