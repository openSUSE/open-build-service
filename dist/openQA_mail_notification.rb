#!/usr/bin/ruby

require 'net/https'
require 'net/smtp'
require 'uri'
require 'json'
require 'mail'
require 'yaml/store'

FROM = 'obs-admin@opensuse.org'
TO = 'obs-tests@opensuse.org'
SMTP_SERVER = ''
OPEN_QA = 'https://openqa.opensuse.org/'
DISTRIBUTION = 'obs'
VERSION = 'Unstable'
GROUP = '17'

def get_build_information
  begin
    uri = URI.parse("#{OPEN_QA}api/v1/jobs?distri=#{DISTRIBUTION}&version=#{VERSION}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    JSON.parse(response.body)['jobs'].last
  rescue Exception => ex
    $stderr.puts "Error while fetching openQA data: #{ex.inspect}"
    abort
  end
end

def modules_to_sentence(modules)
  modules.map { |m| "#{m['name']} #{m['result']}" }
end

def build_message(build, successful_modules, failed_modules)
<<MESSAGE_END
See #{OPEN_QA}tests/overview?distri=#{DISTRIBUTION}&version=#{VERSION}&build=#{build}&groupid=#{GROUP}

#{failed_modules.length + successful_modules.length} modules, #{failed_modules.length} failed, #{successful_modules.length} successful

Failed:
#{failed_modules.join("\n")}

Successful:
#{successful_modules.join("\n")}
MESSAGE_END
end

def send_notification(from, to, subject, message)
  begin
    mail = Mail.new do
      from    from
      to      to
      subject subject
      body    message
    end
    settings = { address: SMTP_SERVER, port: 25, enable_starttls_auto: false  }
    settings[:domain] = ENV["HOSTNAME"] if ENV["HOSTNAME"] && !ENV["HOSTNAME"].empty?
    mail.delivery_method :smtp, settings
    puts mail.to_s
    mail.deliver
  rescue Exception => ex
    $stderr.puts "#{SMTP_SERVER}: #{ex.inspect}"
    abort
  end
end

build = get_build_information

store = YAML::Store.new('builds.yml')
last_build = store.transaction { store[:name] }
result = last_build <=> build['name']

unless result == 0
  modules = build['modules']
  successful_modules = modules.select { |m| m['result'] == 'passed' }
  failed_modules = modules.select { |m| m['result'] == 'failed' }
  successful_modules = modules_to_sentence(successful_modules)
  failed_modules = modules_to_sentence(failed_modules)

  subject = "Build #{build['result']} in openQA: #{build['name']}"
  message = build_message(build['settings']['BUILD'], successful_modules, failed_modules)
  send_notification(FROM, TO, subject, message)

  store.transaction do
    store[:name] = build['name']
    store[:last_run] = build['t_finished']
  end
end
