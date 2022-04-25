#!/usr/bin/ruby

require 'net/https'
require 'net/smtp'
require 'uri'
require 'json'
require 'mail'
require 'yaml/store'

FROM = 'obs-admin@opensuse.org'.freeze
TO_SUCCESS = 'obs-tests@opensuse.org'.freeze
TO_FAILED = 'obs-errors@opensuse.org'.freeze
SMTP_SERVER = ''.freeze
OPEN_QA = 'https://openqa.opensuse.org/'.freeze
DISTRIBUTION = 'obs'.freeze
VERSIONS = ['Unstable', '2.9', '2.8'].freeze
GROUP = '17'.freeze

def get_build_information(version)
  uri = URI.parse("#{OPEN_QA}api/v1/jobs?distri=#{DISTRIBUTION}&version=#{version}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  JSON.parse(response.body)['jobs'].last
rescue Exception => e
  warn "Error while fetching openQA data: #{e.inspect}"
  abort
end

def modules_to_sentence(modules)
  modules.map { |m| "#{m['name']} #{m['result']}" }
end

def build_message(build, successful_modules, failed_modules, version)
  <<~MESSAGE_END
    See #{OPEN_QA}tests/overview?distri=#{DISTRIBUTION}&version=#{version}&build=#{build}&groupid=#{GROUP}

    #{failed_modules.length + successful_modules.length} modules, #{failed_modules.length} failed, #{successful_modules.length} successful

    Failed:
    #{failed_modules.join("\n")}

    Successful:
    #{successful_modules.join("\n")}
  MESSAGE_END
end

def send_notification(from, to, subject, message)
  mail = Mail.new do
    from    from
    to      to
    subject subject
    body    message
  end
  settings = { address: SMTP_SERVER, port: 25, enable_starttls_auto: false }
  settings[:domain] = ENV.fetch('HOSTNAME') if ENV.fetch('HOSTNAME', nil).present?
  mail.delivery_method :smtp, settings
  mail.deliver
rescue Exception => e
  warn "#{SMTP_SERVER}: #{e.inspect}"
  abort
end

VERSIONS.each do |version|
  build = get_build_information(version)
  store = YAML::Store.new("builds-#{version}.yml")
  last_build = store.transaction { store[:name] }
  result = last_build <=> build['name']

  next unless result != 0 && build['state'] == 'done'

  modules = build['modules']
  successful_modules = modules.select { |m| m['result'] == 'passed' }
  failed_modules = modules.select { |m| m['result'] == 'failed' }
  successful_modules = modules_to_sentence(successful_modules)
  failed_modules = modules_to_sentence(failed_modules)

  subject = "Build #{build['result']} in openQA: #{build['name']}"
  message = build_message(build['settings']['BUILD'], successful_modules, failed_modules, version)
  to = TO_SUCCESS
  to = TO_FAILED unless failed_modules.empty?
  send_notification(FROM, to, subject, message)

  store.transaction do
    store[:name] = build['name']
    store[:last_run] = build['t_finished']
  end
end
