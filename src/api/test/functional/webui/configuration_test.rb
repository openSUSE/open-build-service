# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::ConfigurationTest < Webui::IntegrationTest
  uses_transaction :test_change_config

  def test_configuration_update # spec/controllers/webui/configuration_controller_spec.rb
    visit configuration_path
    flash_message_type.must_equal :alert
    flash_message.must_equal 'Requires admin privileges'

    login_king to: configuration_path
    title = 'Cool Build Service'
    fill_in 'configuration_title', with: title
    descr = "I don't like long texts - just some chinese: 這兩頭排開離觀止進"
    fill_in 'configuration_description', with: descr
    click_button 'Update'

    flash_message.must_equal 'Configuration was successfully updated.'

    find('#configuration_title').value.must_equal title
    find('#configuration_description').value.must_equal descr
    first('#breadcrump a').text.must_equal title
  end

  def test_architecture_availability # spec/controllers/webui/architectures_controller_spec.rb
    login_king to: architectures_path

    assert Architecture.find_by_name('i586').available
    assert_equal Architecture.find_by_name('s390').available, false

    uncheck('archs[i586]')
    check('archs[s390]')
    click_button 'Update'

    flash_message.must_equal 'Architectures successfully updated.'
    assert_equal Architecture.find_by_name('i586').available, false
    assert_equal Architecture.find_by_name('s390').available, true

    # and revert
    check('archs[i586]')
    uncheck('archs[s390]')
    click_button 'Update'
    assert Architecture.find_by_name( "i586" ).available
    assert_equal Architecture.find_by_name( "s390" ).available, false
  end
end
