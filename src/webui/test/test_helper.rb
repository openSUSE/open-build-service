ENV["RAILS_ENV"] = "test"
require 'simplecov'
require 'simplecov-rcov'
SimpleCov.start 'rails' if ENV["DO_COVERAGE"]

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'test/unit/assertions'

require 'headless'

require 'capybara/rails'
Capybara.default_driver = :selenium
# this is the build service! 2 seconds - HAHAHA
Capybara.default_wait_time = 10

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
    @current_user = user
    if do_assert
      find('#flash-messages').must_have_content("You are logged in now")
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

  def login_king
    login_user("king", "sunflower", false)
  end

  def logout
    @current_user = nil
    ll = page.first('#logout-link')
    ll.click if ll
  end

  def current_user
    @current_user
  end
  
  @@display = nil

  setup do
    if !@@display && ENV['HEADLESS']
      @@display = Headless.new
      @@display.start
    end
    olddriver = Capybara.current_driver
    Capybara.current_driver = :rack_test
    10.times do
      begin
        visit '/'
        ENV['API_STARTED'] = '1'
        break
      rescue Timeout::Error
      end
    end unless ENV['API_STARTED']
    raise "No api" unless ENV['API_STARTED']
    ActiveXML::transport.http_do :post, "/test/test_start"
    Capybara.current_driver = olddriver
    @starttime = Time.now
  end

  teardown do
    dirpath = Rails.root.join("tmp", "capybara")
    htmlpath = dirpath.join(self.__name__ + ".html")
    if !passed?
      Dir.mkdir(dirpath) unless Dir.exists? dirpath
      save_page(htmlpath)
    elsif File.exists?(htmlpath)
      File.unlink(htmlpath)
    end
    logout
    
    Capybara.reset_sessions!
    ActiveXML::transport.http_do(:post, "/test/test_end", timeout: 100)
    Capybara.use_default_driver
    Rails.cache.clear
    #puts "#{self.__name__} took #{Time.now - @starttime}"
  end

  # ============================================================================
  # Checks if a flash message is displayed on screen
  #
  def flash_message_appeared?
    flash_message_type != nil
  end

  # ============================================================================
  # Returns the text of the flash message currenlty on screen
  # @note Doesn't fail if no message is on screen. Returns empty string instead.
  # @return [String]
  #
  def flash_message
    results = all(:css, "div#flash-messages p")
    if results.empty?
      return "none"
    end
    raise "One flash expected, but we had more." if results.count != 1
    return results.first.text
  end

  # ============================================================================
  # Returns the text of the flash messages currenlty on screen
  # @note Doesn't fail if no message is on screen. Returns empty list instead.
  # @return [array]
  #
  def flash_messages
    results = all(:css, "div#flash-messages p")
    ret = []
    results.each { |r| ret << r.text }
    return ret
  end

  # ============================================================================
  # Returns the type of the flash message currenlty on screen
  # @note Does not fail if no message is on screen! Returns nil instead!
  # @return [:info, :alert]
  #
  def flash_message_type
    result = first(:css, "div#flash-messages span")
    return nil unless result
    return :info  if result["class"].include? "info"
    return :alert if result["class"].include? "alert"
  end

  # helper function for teardown
  def delete_package project, package
    visit package_show_path(package: package, project: project)
    find(:id, 'delete-package').click
    find(:id, 'del_dialog').must_have_text 'Delete Confirmation'
    find_button("Ok").click
    find('#flash-messages').must_have_text "Package '#{package}' was removed successfully"
  end

end
