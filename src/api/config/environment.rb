# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION

APIDOCS_LOCATION = File.expand_path("#{RAILS_ROOT}/../../docs/api/html/")
SCHEMA_LOCATION = File.expand_path("#{RAILS_ROOT}/public/schema")+"/"

require "common/libxmlactivexml"
require 'custom_logger'

# define our current api version
api_version = '2.0.90'

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence those specified here
  
  # Skip frameworks you're not going to use
  config.frameworks -= [ :action_web_service, :active_resource ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # RAILS_ROOT is not working directory when running under lighttpd, so it has
  # to be added to load path
  #config.load_paths << RAILS_ROOT unless config.load_paths.include? RAILS_ROOT

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  # config.action_controller.session_store = :active_record_store

  # put the rubygem requirements here for a clean handling
  # rake gems:install (installs the needed gems)
  # rake gems:unpack (this unpacks the gems to vendor/gems)

  config.gem 'daemons'
  config.gem 'delayed_job'
  config.gem 'exception_notification'

  config.action_controller.session = {
    :session_key => "_frontend_session",
    :secret => "ad9712p8349zqmowiefzhiuzgfp9s8f7qp83947p98weap98dfe7"
  }

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  config.cache_store = :compressed_mem_cache_store, 'localhost:11211', {:namespace => 'obs-api'}

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc
  
  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  # config.active_record.schema_format = :ruby

  config.logger = NiceLogger.new(config.log_path)
  # See Rails::Configuration for more options
end

# Include your application configuration below


# minimum count of rating votes a project/package needs to
# be taken in account for global statistics
MIN_VOTES_FOR_RATING = 3

ActionController::Base.perform_caching = true

ActiveRbac.controller_layout = "rbac"

ActiveXML::Base.config do |conf|
  conf.lazy_evaluation = true

  conf.setup_transport do |map|
    map.default_server :rest, "#{SOURCE_HOST}:#{SOURCE_PORT}"

    map.connect :project, "bssql:///"
    map.connect :package, "bssql:///"

    #map.connect :project, "rest:///source/:name/_meta",
    #    :all    => "rest:///source/"
    #map.connect :package, "rest:///source/:project/:name/_meta",
    #    :all    => "rest:///source/:project"
    
    map.connect :bsrequest, "rest:///request/:id",
      :all => "rest:///request"

    map.connect :collection, "rest:///search/:what?:match",
      :id => "rest:///search/:what/id?:match",
      :package => "rest:///search/package?:match",
      :project => "rest:///search/project?:match"

  end
end

ExceptionNotifier.exception_recipients = CONFIG['exception_recipients']
ExceptionNotifier.sender_address = %("OBS API" <admin@opensuse.org>)

if defined? API_DATE
  CONFIG['version'] = api_version + ".git" + API_DATE
else
  CONFIG['version'] = api_version
end

LibXML::XML::Error.set_handler(&LibXML::XML::Error::QUIET_HANDLER)

