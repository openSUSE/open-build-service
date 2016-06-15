require_relative '../../test_helper'

class Webui::WebuiControllerTest < Webui::IntegrationTest
  setup do
    @before = CONFIG['proxy_auth_mode']
    # Fake proxy mode
    CONFIG['proxy_auth_mode'] = :on
  end

  teardown do
    CONFIG['proxy_auth_mode'] = @before
  end

  def test_check_user_in_proxy # spec/controllers/webui/webui_controller_spec.rb
    use_js

    # No user set by proxy
    visit search_path
    page.must_have_text "Log In"

    # Existing OBS user
    page.driver.add_header('X_USERNAME', 'tom')

    visit search_path
    assert_equal "tom", find('#link-to-user-home').text, "Should log in existing users"

    # New OBS user
    page.driver.add_header('X_USERNAME', 'new_user')
    page.driver.add_header('X_EMAIL', 'new_user@obs.com')
    page.driver.add_header('X_FIRSTNAME', 'Bob')
    page.driver.add_header('X_LASTNAME', 'Geldof')

    visit search_path

    user = User.find_by(login: "new_user")
    assert user, "Should create a new user"
    assert_equal "Bob Geldof", user.realname
    assert_equal "new_user@obs.com", user.email
    assert_equal "new_user", find('#link-to-user-home').text, "Should log in new user"
    # cleanup
    User.current = user
    Project.find_by(name: 'home:new_user').destroy
  end
end
