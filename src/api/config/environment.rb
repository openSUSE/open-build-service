# frozen_string_literal: true
# Be sure to restart your web server when you modify this file.

# Load the rails application
require_relative 'application'

path = Rails.root.join('config', 'options.yml')

begin
  CONFIG = YAML.load_file(path)
rescue Exception
  puts "Error while parsing config file #{path}"
  # rubocop:disable Style/MutableConstant
  CONFIG = {}
  # rubocop:enable Style/MutableConstant
end

CONFIG['schema_location'] ||= File.expand_path('public/schema') + '/'
CONFIG['apidocs_location'] ||= File.expand_path('../docs/api/html/')
CONFIG['global_write_through'] ||= true
CONFIG['proxy_auth_mode'] ||= :off
CONFIG['frontend_ldap_mode'] ||= :off

# Initialize the rails application
OBSApi::Application.initialize!
