# Be sure to restart your web server when you modify this file.

# Load the rails application
require File.expand_path('../application', __FILE__)

path = Rails.root.join("config", "options.yml")

begin
  CONFIG = YAML.load_file(path)
rescue Exception
  puts "Error while parsing config file #{path}"
  CONFIG = Hash.new
end

CONFIG['schema_location'] ||= File.expand_path("public/schema")+"/"
CONFIG['apidocs_location'] ||= File.expand_path("../../docs/api/html/")
CONFIG['global_write_through'] ||= true
CONFIG['proxy_auth_mode'] ||= :off
CONFIG['frontend_ldap_mode'] ||= :off

# use hardcoded source server port for test and development
# used in start_test_backend script
if ENV['RAILS_ENV'] == 'test'
  CONFIG['source_port'] = 3200
elsif ENV['RAILS_ENV'] == 'development'
  CONFIG['source_port'] = 6200
end

# Initialize the rails application
OBSApi::Application.initialize!

