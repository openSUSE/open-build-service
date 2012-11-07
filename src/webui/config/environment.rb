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

CONFIG['download_url'] ||= 'http://download.opensuse.org/repositories'

# Initialize the rails application
OBSWebUI::Application.initialize!


#TODO: Check back if further stuff can be obsoleted:
#

ActionController::Base.relative_url_root = CONFIG['relative_url_root'] if CONFIG['relative_url_root']

require 'ostruct'

SOURCEREVISION = 'master'
begin
  SOURCEREVISION = File.open("#{Rails.root}/REVISION").read
rescue Errno::ENOENT
end
CONFIG['proxy_auth_mode'] ||= :off
CONFIG['frontend_ldap_mode'] ||= :off

CONFIG['apidocs_location'] ||= File.expand_path("../../docs/api/html/")
CONFIG['schema_location'] ||= File.expand_path("../../docs/api/api/")

