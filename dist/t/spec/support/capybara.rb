require 'capybara'
require 'capybara/apparition'
require 'capybara/dsl'
require 'socket'

Capybara.register_driver :selenium_chrome_headless do |app|
  options = {
    window_size:         [1280, 1024],
    js_errors:           false,
    headless:            true,
    ignore_https_errors: true,
    w3c:                 false,
    browser_options:     { 'disable-gpu': true, 'no-sandbox': true }
  }
  Capybara::Apparition::Driver.new(app, options)
end

Capybara.default_driver = :selenium_chrome_headless
Capybara.default_max_wait_time = 20 # We increase this value because we depend on the load of the system and resource constraints
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

Capybara.app_host = ENV.fetch('SMOKETEST_HOST', "https://#{hostname}")

RSpec.configure do |config|
  config.include Capybara::DSL
end
