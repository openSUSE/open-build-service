# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence those specified here

  # Skip frameworks you're not going to use
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )
  if( RAILS_ENV ==  'production' )
    config.load_paths << File.expand_path("/srv/www/opensuse/common/current/lib")
  else
    config.load_paths << File.expand_path("#{RAILS_ROOT}/../common/lib")
  end

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  # config.action_controller.session_store = :active_record_store

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc

  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  # config.active_record.schema_format = :ruby

  # See Rails::Configuration for more options
end

# Add new inflection rules using the following format
# (all these examples are active by default):
# Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# Include your application configuration below


require 'custom_logger'
RAILS_DEFAULT_LOGGER.formatter = Logger::CustomFormatter.new

require 'activexml'

#TRANSPORT = Suse::Frontend.new("http://#{FRONTEND_HOST}:#{FRONTEND_PORT}")

ActiveXML::Base.config do |conf|
  conf.setup_transport do |map|
    map.default_server :rest, "#{FRONTEND_HOST}:#{FRONTEND_PORT}"

    map.connect :project, "rest:///source/:name/_meta",
        :all    => "rest:///source/"
    map.connect :package, "rest:///source/:project/:name/_meta",
        :all    => "rest:///source/:project"

    #map.connect :tag, "rest:///source/:project/:package/_tags",
    map.connect :tag, "rest:///user/:user/tags/:project/:package",
        :tags_by_user => "rest:///user/:user/tags/_tagcloud",
        :tagcloud  => "rest:///tag/tagcloud"

    map.connect :person, "rest:///person/:login"
    map.connect :unregisteredperson, "rest:///person/register"

    map.connect :platform, "rest:///platform/:project/:name",
        :all    => "rest:///platform/"

    map.connect :directory, "rest:///source/:project/:package"
    map.connect :link, "rest:///source/:project/:package/_link"

    map.connect :result, "rest:///result/:project/:platform/:package/:arch/result"
    map.connect :packstatus, "rest:///result/:project/packstatus?:command"

    map.connect :collection, "rest:///search/:what?match=:predicate",
        :tag => "rest:///tag/:tagname/:type",
        :tags_by_user => "rest:///user/:user/tags/:type"

    map.connect :workerstatus, "rest:///build/_workerstatus",
        :all => "rest:///build/_workerstatus"

    # Statistics
    map.connect :latestadded, "rest:///statistics/latest_added?limit=:limit",
      :all => "rest:///statistics/latest_added"
    map.connect :latestupdated, "rest:///statistics/latest_updated?limit=:limit",
      :all => "rest:///statistics/latest_updated"
    map.connect :downloadcounter, "rest:///statistics/download_counter" +
      "/:project/:package/:repository/:architecture?concat=:concat",
      :arch => "rest:///statistics/download_counter?architecture=:arch",
      :repo => "rest:///statistics/download_counter?repository=:repo",
      :all => "rest:///statistics/download_counter"

  end
end
