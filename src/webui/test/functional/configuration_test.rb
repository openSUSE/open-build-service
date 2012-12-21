# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ConfigurationTest < ActionDispatch::IntegrationTest

  test "change config" do
    visit configuration_path
    assert_equal :alert, flash_message_type
    assert_equal "Requires admin privileges", flash_message

    login_king
    visit configuration_path
    title = "Cool Build Service"
    fill_in "title", with: title
    descr = "I don't like long texts - just some chinese: 這兩頭排開離觀止進"
    fill_in "description", with: descr
    click_button "Update"

    assert_equal "Updated configuration", flash_message

    assert_equal title, find("#title").value
    assert_equal descr, find("#description").value

    assert_equal title, first("#breadcrump a").text
  end

end

