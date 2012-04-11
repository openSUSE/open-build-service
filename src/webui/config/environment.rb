# Be sure to restart your web server when you modify this file.

# Load the rails application
require File.expand_path('../application', __FILE__)

config_path = Rails.root.join('config', 'options.yml')

begin
  CONFIG = YAML.load_file(config_path)
rescue Exception => e
  puts "Error while parsing config file #{config_path}"
  CONFIG = Hash.new
end

CONFIG['apidocs_location'] ||= File.expand_path('../../docs/api/html/')
CONFIG['schema_location'] ||= "#{File.expand_path('public/schema')}/"
CONFIG['download_url'] ||= 'http://download.opensuse.org/repositories'

# Initialize the rails application
OBSWebUI::Application.initialize!


#TODO: Check back if further stuff can be obsoleted:
#

ActionController::Base.relative_url_root = CONFIG['relative_url_root'] if CONFIG['relative_url_root']

require 'ostruct'

# Exception notifier plugin configuration
ExceptionNotifier.sender_address = '"OBS Webclient" <admin@opensuse.org>'
ExceptionNotifier.email_prefix = '[OBS WebUI Error] '
ExceptionNotifier.exception_recipients = CONFIG['exception_recipients']

SOURCEREVISION = 'master'
begin
  SOURCEREVISION = File.open("#{RAILS_ROOT}/REVISION").read
rescue Errno::ENOENT
end
unless defined?(PROXY_AUTH_MODE) and not PROXY_AUTH_MODE.blank?
  PROXY_AUTH_MODE = :off
end
unless defined?(FRONTEND_LDAP_MODE) and not FRONTEND_LDAP_MODE.blank?
  FRONTEND_LDAP_MODE = :off
end
