# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

RAILS_GEM_VERSION = '~>2.3.8' unless defined? RAILS_GEM_VERSION

APIDOCS_LOCATION = File.expand_path("#{RAILS_ROOT}/../../docs/api/html/")
SCHEMA_LOCATION = File.expand_path("#{RAILS_ROOT}/public/schema")+"/"

require "activexml/activexml"

# define our current api version
api_version = '2.3.0'

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

  config.gem 'nokogiri'
  config.gem 'daemons'
  config.gem 'delayed_job'
  config.gem 'exception_notification'
  config.gem 'erubis'
  config.gem 'rails_xss'
  config.gem 'json'
  config.gem 'ci_reporter', :lib => false # ci_reporter generates XML reports for Test::Unit
  config.gem 'rdoc'

  # default secret
  secret = "ad9712p8349zqmowiefzhiuzgfp9s8f7qp83947p98weap98dfe7"
  if File.exist? "#{RAILS_ROOT}/config/secret.key"
    file = File.open( "#{RAILS_ROOT}/config/secret.key", "r" )
    secret = file.readline
  end
  config.action_controller.session = {
    :key => "_frontend_session",
    :secret => secret
  }

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  config.cache_store = :compressed_mem_cache_store, 'localhost:11211', {:namespace => 'obs-api'}

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc
  
  config.active_record.schema_format = :sql

  unless ENV['FCGI_INSTANCE_NAME'].nil?
    config.log_path = "#{RAILS_ROOT}/log/#{ENV['FCGI_INSTANCE_NAME']}.log"
  end

  # See Rails::Configuration for more options
  config.after_initialize do
    ExceptionNotifier.exception_recipients = CONFIG["exception_recipients"]
    ExceptionNotifier.sender_address = CONFIG["exception_sender"]
  end unless Rails.env.test?
end

# rake gems:install doesn't load initializers, load options manually if CONFIG is undefined
require File.join(File.dirname(__FILE__), 'initializers', 'options') unless defined?(CONFIG)

ActionController::Base.perform_caching = true
ActiveRbac.controller_layout = "rbac"

unless defined?(SOURCE_PROTOCOL) and not SOURCE_PROTOCOL.blank?
  SOURCE_PROTOCOL = "http"
end

ActiveXML::Base.config do |conf|
  conf.lazy_evaluation = true

  conf.setup_transport do |map|
    map.default_server :rest, "#{SOURCE_PROTOCOL}://#{SOURCE_HOST}:#{SOURCE_PORT}"

    map.connect :project, "bssql:///"
    map.connect :package, "bssql:///"

    map.connect :directory, "rest:///source/:project/:package?:expand&:rev&:meta&:linkrev&:emptylink&:view&:extension&:lastworking&:withlinked&:deleted"
    map.connect :jobhistory, "rest:///build/:project/:repository/:arch/_jobhistory?:package&:limit&:code"

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

if defined? API_DATE
  CONFIG['version'] = api_version + ".git" + API_DATE
else
  CONFIG['version'] = api_version
end

