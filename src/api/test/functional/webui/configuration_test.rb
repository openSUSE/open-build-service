# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::ConfigurationTest < Webui::IntegrationTest

  uses_transaction :test_change_config

  test 'change config' do
    visit configuration_path
    flash_message_type.must_equal :alert
    flash_message.must_equal 'Requires admin privileges'

    login_king to: configuration_path
    title = 'Cool Build Service'
    fill_in 'title', with: title
    descr = "I don't like long texts - just some chinese: 這兩頭排開離觀止進"
    fill_in 'description', with: descr
    click_button 'Update'

    flash_message.must_equal 'Updated configuration'

    find('#title').value.must_equal title
    find('#description').value.must_equal descr

    first('#breadcrump a').text.must_equal title
  end

end

