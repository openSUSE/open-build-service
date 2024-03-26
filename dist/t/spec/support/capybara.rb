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
Capybara.default_max_wait_time = 6
Capybara.javascript_driver = :selenium_chrome_headless
Capybara.save_path = '/tmp/rspec_screens'
# Attempt to click the associated label element if a checkbox/radio button are non-visible (This is especially useful for Bootstrap custom controls)
Capybara.automatic_label_click = true

# Set hostname
begin
  hostname = Addrinfo.getaddrinfo(Socket.gethostname, 443, nil, :STREAM).first.getnameinfo[0]
rescue SocketError
  hostname = ''
end
ipaddress = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
hostname = ipaddress if hostname.empty?

Capybara.app_host = ENV.fetch('SMOKETEST_HOST', "https://#{hostname}")

RSpec.configure do |config|
  config.include Capybara::DSL
  config.before do
    page.driver.add_headers('User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64; rv:85.0) Gecko/20100101 Firefox/85.0')
  end
end
