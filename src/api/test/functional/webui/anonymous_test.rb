require_relative '../../test_helper'

class Webui::AnonymousTest < Webui::IntegrationTest
  def test_Disable_anonymous_access # -> spec/controllers/webui/webui_controller_spec.rb
    # Check general access
    visit root_path
    page.must_have_text 'Locations'
    page.must_have_text 'Latest Updates'
    first(:link, 'All Projects').click
    page.must_have_text 'This is a base distro'

    # Forbid anonymous users in the config
    config = ::Configuration.first
    config.anonymous = false
    config.save!

    # Try to access something
    visit root_path
    page.wont_have_text 'Locations'
    first(:link, 'All Projects').click
    flash_message.must_equal 'No anonymous access. Please log in!'
    flash_message_type.must_equal :alert

    # Reset config
    config.anonymous = true
    config.save!
  end
end
