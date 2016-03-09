require 'capybara'
require 'capybara/dsl'
require 'capybara/poltergeist'
require 'socket'

include Capybara::DSL

Capybara.default_max_wait_time = 6

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, debug: false, timeout: 30)
end

Capybara.default_driver = :poltergeist
Capybara.javascript_driver = :poltergeist

begin
	hostname = Socket.gethostbyname(Socket.gethostname).first
rescue
	hostname = ""
ipaddress = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
if hostname.empty?
  hostname = ipaddress
end
Capybara.app_host = "https://" + hostname
