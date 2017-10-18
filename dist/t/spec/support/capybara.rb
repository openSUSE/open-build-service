require 'capybara'
require 'capybara/dsl'
require 'capybara/poltergeist'
require 'socket'

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, debug: false, timeout: 60)
end

Capybara.default_driver = :poltergeist
Capybara.javascript_driver = :poltergeist
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
