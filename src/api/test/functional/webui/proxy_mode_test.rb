require_relative '../../test_helper'

SimpleCov.command_name 'test:proxy_mode'

class Webui::ProxyModeTest < Webui::IntegrationTest
  def test_access_as_new_user
    if CONFIG['proxy_auth_mode'] != :on
      skip("This test depends on proxy_auth_mode being :on which is isn't...")
    end
    user = User.find_by(login: 'pico')
    user.destroy if user
    visit '/home'
    assert_equal '/user/show/pico', page.current_path
    user = User.find_by(login: 'pico')
    assert_not_nil user
    assert_equal user.state, User::STATES['confirmed']
    assert_equal user.realname, "Arnold Pico Schütz"
    assert_equal user.email, "pico@werder.de"
    user.destroy
  end

  def test_access_as_existing_user
    if CONFIG['proxy_auth_mode'] != :on
      skip("This test depends on proxy_auth_mode being :on which is isn't...")
    end
    assert_nil User.find_by(login: 'pico')
    # We use the data from ProxyModeFaker...
    User.create!(login: 'pico',
                 email: 'pico@werder.de',
                 realname: "Arnold Pico Schütz",
                 password: '123456',
                 password_confirmation: '123456')
    visit '/home'
    assert_equal '/user/show/pico', page.current_path
    User.find_by(login: 'pico').destroy
  end
end
