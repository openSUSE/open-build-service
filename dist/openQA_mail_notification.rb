require 'net/https'
require 'net/smtp'
require 'uri'
require 'json'

FROM = 'obs-admin@opensuse.org'
TO = 'obs-test@opensuse.org'
SMTP_SERVER = ''
OPEN_QA = 'https://openqa.opensuse.org/api/v1'
DISTRIBUTION = 'obs'
VERSION = 'unstable'
GROUP = '17'

def get_build_information
  uri = URI.parse("#{OPEN_QA}/jobs?distri=#{DISTRIBUTION}&version=#{VERSION}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  JSON.parse(response.body)['jobs']
end

def modules_to_sentence(modules)
  modules.map { |m| "#{m['name']} #{m['result']}" }
end

def build_message(name, result, build, successful_modules, failed_modules)
<<MESSAGE_END
From: #{FROM} <#{FROM}>
To: #{TO} <#{TO}>
Subject: openQA test for #{name} #{result}

See #{OPEN_QA}/tests/overview?distri=#{DISTRIBUTION}&version=#{VERSION}&build=#{build}&groupid=#{GROUP}

#{failed_modules.length + successful_modules.length} modules, #{failed_modules.length} failed, #{successful_modules.length} successful

Failed:
#{failed_modules.join("\n")}

Successful:
#{successful_modules.join("\n")}
MESSAGE_END
end

def send_notification(from, to, message)
  Net::SMTP.start(SMTP_SERVER) do |smtp|
    smtp.send_message message, from, to
  end
end

response = get_build_information

modules = response.last['modules']
successful_modules = modules.select { |m| m['result'] == 'passed' }
failed_modules = modules.select { |m| m['result'] == 'failed' }
successful_modules = modules_to_sentence(successful_modules)
failed_modules = modules_to_sentence(failed_modules)

message = build_message(response.last['name'], response.last['result'], response.last['settings']['BUILD'], successful_modules, failed_modules)
send_notification(FROM, TO, message)
