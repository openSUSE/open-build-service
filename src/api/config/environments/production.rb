# Settings specified here will take precedence over those in config/environment.rb

OBSApi::Application.configure do

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Use a different logger for distributed setups
  # config.logger        = SyslogLogger.new
  config.log_level = :info

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host                  = "http://assets.example.com"

  # Disable delivery errors if you bad email addresses should just be ignored
  # config.action_mailer.raise_delivery_errors = false

  config.active_support.deprecation = :log
 
   # Enable serving of images, stylesheets, and javascripts from an asset server
   # config.action_controller.asset_host                  = "http://assets.example.com"
 
  config.cache_store = :dalli_store, 'localhost:11211', {:namespace => 'obs-api', :compress => true }

end


#require 'hermes'
#Hermes::Config.setup do |hermesconf|
#  hermesconf.dbhost = 'storage'
#  hermesconf.dbuser = 'hermes'
#  hermesconf.dbpass = ''
#  hermesconf.dbname = 'hermes'
#end

# disabled on production for performance reasons
# CONFIG['response_schema_validation'] = true

#require 'memory_debugger'
# dumps the objects after every request
#config.middleware.insert(0, MemoryDebugger)

#require 'memory_dumper'
# dumps the full heap after next request on SIGURG
#config.middleware.insert(0, MemoryDumper)

