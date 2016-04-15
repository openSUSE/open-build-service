require 'capybara'
require 'capybara/poltergeist'
require 'socket'

Capybara.default_max_wait_time = 6

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, debug: false, timeout: 8)
end

Capybara.default_driver = :poltergeist
Capybara.javascript_driver = :poltergeist

begin
  hostname = Socket.gethostbyname(Socket.gethostname).first
rescue SocketError
  hostname = ""
end
ipaddress = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
if hostname.empty?
  hostname = ipaddress
end
Capybara.app_host = "https://" + hostname
