# Be sure to restart your web server when you modify this file.

# Load the rails application
require_relative 'application'

path = Rails.root.join("config/options.yml")

begin
  config = YAML.load_file(path, aliases: true)
  if config.key?(Rails.env)
    CONFIG = config[Rails.env]
  else
    # FIXME: Remove with the next stable release (v2.10 or v3.0)
    puts "DEPRECATED: Please update your options.yml by running 'rake migrate_options_yml'"
    CONFIG = config
  end
rescue StandardError
  puts "Error while parsing config file #{path}"
  # rubocop:disable Style/MutableConstant
  CONFIG = {}
  # rubocop:enable Style/MutableConstant
end

CONFIG['schema_location'] ||= "#{File.expand_path('public/schema')}/"
CONFIG['global_write_through'] = true if CONFIG['global_write_through'].nil?
CONFIG['proxy_auth_mode'] ||= :off
CONFIG['force_ssl'] = true if CONFIG['force_ssl'].nil?
CONFIG['assume_ssl'] = false if CONFIG['assume_ssl'].nil?

# Initialize the rails application
OBSApi::Application.initialize!
