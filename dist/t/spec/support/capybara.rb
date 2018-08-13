require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'
require 'socket'

Selenium::WebDriver::Chrome.driver_path = '/usr/lib64/chromium/chromedriver'

Capybara.register_driver :selenium_chrome_headless do |app|
  browser_options = ::Selenium::WebDriver::Chrome::Options.new
  browser_options.args << '--headless'
  browser_options.args << '--no-sandbox'
  browser_options.args << '--allow-insecure-localhost'
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
end

Capybara.default_driver = :selenium_chrome_headless
Capybara.javascript_driver = :selenium_chrome_headless
Capybara.save_path = '/tmp/rspec_screens'

# Set hostname
begin
  hostname = Socket.gethostbyname(Socket.gethostname).first
rescue SocketError
  hostname = ""
end
ipaddress = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
if hostname.empty?
  hostname = ipaddress
end

Capybara.app_host = ENV['SMOKETEST_HOST'].nil? ? "https://#{hostname}" : "http://localhost:3000"

RSpec.configure do |config|
  config.include Capybara::DSL
end
