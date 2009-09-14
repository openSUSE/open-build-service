# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

RAILS_GEM_VERSION = '~> 2.1' unless defined? RAILS_GEM_VERSION

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence those specified here
  
  # Skip frameworks you're not going to use
  config.frameworks -= [ :action_web_service, :active_resource ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )
  if( RAILS_ENV ==  'production' )
    config.load_paths << File.expand_path("/srv/www/opensuse/common/current/lib")
  else
    config.load_paths << File.expand_path("#{RAILS_ROOT}/../common/lib")
  end

  # RAILS_ROOT is not working directory when running under lighttpd, so it has
  # to be added to load path
  #config.load_paths << RAILS_ROOT unless config.load_paths.include? RAILS_ROOT

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  # config.action_controller.session_store = :active_record_store

  config.action_controller.session = {
    :session_key => "_frontend_session",
    :secret => "ad9712p8349zqmowiefzhiuzgfp9s8f7qp83947p98weap98dfe7"
  }

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

API_VERSION="0.1.1"


# minimum count of rating votes a project/package needs to
# be taken in account for global statistics
MIN_VOTES_FOR_RATING = 3


# activate / enable caching with the action_cache plugin
require 'action_cache'
ActionController::Base.perform_caching = true

ActiveRbac.controller_layout = "rbac"

#require 'custom_logger'
#RAILS_DEFAULT_LOGGER.formatter = Logger::CustomFormatter.new

require 'rails_put_fix'
require 'rails_unescape_fix'
require 'array_count_for_2_1_fix'

require 'activexml'
#require 'smartactivexml'
#require 'custom_dispatcher'

#Dependencies.log_activity = true
#Dependencies.load_once_paths << "#{RAILS_ROOT}/lib"

# was needed for rails < 2.3
#module ActionController::Routing
#  remove_const :SEPARATORS
#  SEPARATORS = %w(/ ; ?)
#end

ActiveXML::Base.config do |conf|
  if RAILS_ENV == "test"
    # changed metadata is not written to the backend server
    conf.global_write_through = false
  end

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

    map.connect :packstatus, "rest:///status/:project?summaryonly=:summaryonly"

    map.connect :collection, "rest:///search/:what?:match",
      :id => "rest:///search/:what/id?:match",
      :package => "rest:///search/package?:match",
      :project => "rest:///search/project?:match"

  end
end
