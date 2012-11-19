ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'test/unit/assertions'

require 'headless'

require 'capybara/rails'
Capybara.default_driver = :selenium

class ActionDispatch::IntegrationTest

  # Make the Capybara DSL available
  include Capybara::DSL

  # somewhen in the future we will have the API use transactions for webui tests ;)
  self.use_transactional_fixtures = false

  def login_user(user, password, do_assert = true)
    visit "/"
    click_link 'login-trigger'
    within('#login-form') do
      fill_in 'Username', with: user
      fill_in 'Password', with: password
      click_button 'Login'
    end
    if do_assert
      assert find('#flash-messages').has_content?("You are logged in now")
    end
  end

  # will provide a user without special permissions
  def login_tom
    login_user('tom', 'thunder')
  end

  def login_Iggy
    login_user('Iggy', 'asdfasdf')
  end

  def login_adrian
    login_user('adrian', 'so_alone')
  end

  def logout
    ll = page.first('#logout-link')
    ll.click if ll
  end

  @@display = nil

  setup do
    if !@@display && ENV['HEADLESS']
      @@display = Headless.new
      @@display.start
    end
    5.times do
      begin
        visit '/main/startme'
        ENV['API_STARTED'] = '1'
        break
      rescue Timeout::Error
      end
    end unless ENV['API_STARTED']
    ActiveXML::transport.direct_http(URI("/test/test_start"))
  end

  teardown do
    logout
    Capybara.reset_sessions!
    ActiveXML::transport.direct_http(URI("/test/test_end"))
  end
end
