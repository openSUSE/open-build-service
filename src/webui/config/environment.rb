# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION
# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

require "common/libxmlactivexml"
require 'custom_logger'

init = Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence those specified here

  # Skip frameworks you're not going to use
  config.frameworks -= [ :action_web_service, :active_resource ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake create_sessions_table')
  config.action_controller.session_store = :active_record_store
  config.action_controller.session = {
    :prefix => "ruby_webclient_session",
    :session_key => "opensuse_webclient_session",
    :secret => "iofupo3i4u5097p09gfsnaf7g8974lh1j3khdlsufdzg9p889234"
  }

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  config.gem 'gruff'
  config.gem 'daemons'
  config.gem 'delayed_job'
  config.gem 'libxml-ruby'
  config.gem 'exception_notification'

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc

  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  # config.active_record.schema_format = :ruby

  config.cache_store = :compressed_mem_cache_store, 'localhost:11211', {:namespace => 'obs-webclient'}

  # See Rails::Configuration for more options

  config.logger = NiceLogger.new(config.log_path)

end

ActionController::Base.relative_url_root = CONFIG['relative_url_root'] if CONFIG['relative_url_root']

require 'ostruct'
require "cache_immutable_fix.rb"

# Exception notifier plugin configuration
ExceptionNotifier.sender_address = %("OBS Webclient" <admin@opensuse.org>)
ExceptionNotifier.email_prefix = "[OBS web error] "
ExceptionNotifier.exception_recipients = CONFIG['exception_recipients']

MONITOR_IMAGEMAP = { 
      'pc_waiting' => [
        ["i586", 'waiting_i586'],
        ["x86_64", 'waiting_x86_64'] ],
      'pc_blocked' => [
        ["i586", 'blocked_i586' ],
        ["x86_64", 'blocked_x86_64'] ],
      'pc_workers' => [
        ["idle", 'idle_x86_64' ],
        ['building', 'building_x86_64' ] ],
      'ppc_waiting' => [
        ["ppc", 'waiting_ppc'],
        ["ppc64", 'waiting_ppc64'] ],
      'ppc_blocked' => [
        ["ppc", 'blocked_ppc' ],
        ["ppc64", 'blocked_ppc64'] ],
      'ppc_workers' => [
        ["idle", 'idle_ppc64' ],
        ['building', 'building_ppc64' ] ],
      'arm_waiting' => [
        ["armv5", 'waiting_armv5el'],
        ["armv7", 'waiting_armv7el'] ],
      'arm_blocked' => [
        ["armv5", 'blocked_armv5el' ],
        ["armv7", 'blocked_armv7el'] ]
    }

if CONFIG['visible_architectures']
   VISIBLE_ARCHITECTURES=CONFIG['visible_architectures']
else
   VISIBLE_ARCHITECTURES=[ :i586, :x86_64 ]
end
if CONFIG['default_enabled_architectures']
   DEFAULT_ENABLED_ARCHITECTURES=CONFIG['default_enabled_architectures']
else
   DEFAULT_ENABLED_ARCHITECTURES=[ :i586, :x86_64 ]
end

ActiveXML::Base.config do |conf|
  conf.setup_transport do |map|
    map.default_server :rest, "#{FRONTEND_HOST}:#{FRONTEND_PORT}"

    map.connect :project, "rest:///source/:name/_meta?:view",
      :all    => "rest:///source/",
      :delete => "rest:///source/:name?:force"
    map.connect :package, "rest:///source/:project/:name/_meta?:view",
      :all    => "rest:///source/:project"

    map.connect :tagcloud, "rest:///tag/tagcloud?limit=:limit",
      :alltags  => "rest:///tag/tagcloud?limit=:limit",
      :mytags => "rest:///user/:user/tags/_tagcloud?limit=:limit",
      :hierarchical_browsing => "rest:///tag/tagcloud?limit=:limit"

    map.connect :tag, "rest:///user/:user/tags/:project/:package",
      :tags_by_object => "rest:///source/:project/:package/_tags"

    map.connect :person, "rest:///person/:login"
    map.connect :unregisteredperson, "rest:///person/register"

    map.connect :architecture, "rest:///architecture"

    map.connect :wizard, "rest:///source/:project/:package/_wizard?:response"

    map.connect :directory, "rest:///source/:project/:package?:expand"
    map.connect :link, "rest:///source/:project/:package/_link"
    map.connect :service, "rest:///source/:project/:package/_service"
    map.connect :jobhislist, "rest:///build/:project/:name/:arch/_jobhistory?:limit"

    map.connect :buildresult, "rest:///build/:project/_result?:view&:package&:code&:lastbuild&:arch&:repository"
    map.connect :fileinfo, "rest:///build/:project/:repository/:arch/:package/:filename?:view"

    map.connect :result, "rest:///result/:project/:platform/:package/:arch/result"
    map.connect :packstatus, "rest:///result/:project/packstatus?:command"

    map.connect :collection, "rest:///search/:what?match=:predicate",
      :id => "rest:///search/:what/id?match=:predicate",
      :tag => "rest:///tag/:tagname/:type",
      :tags_by_user => "rest:///user/:user/tags/:type",
      :hierarchical_browsing => "rest:///tag/browsing/_hierarchical?tags=:tags"

    map.connect :request, "rest:///request/:id", :create => "rest:///request?cmd=create"

    map.connect :packageattribute, "rest:///search/attribute?:namespace&:name&:project"
 
    map.connect :attribute, "rest:///source/:project/:package/_attribute/:attribute",
      :project => "rest:///source/:project/_attribute/:attribute",
      :namespaces => "rest:///attribute",
      :namespace_config => "rest:///attribute/:namespace/_meta",
      :config => "rest:///attribute/:namespace/:attribute/_meta",
      :attributes => "rest:///attribute/:namespace"   
 
    # Monitor
    map.connect :workerstatus, 'rest:///status/workerstatus',
      :all => 'rest:///status/workerstatus'

    # Statistics
    map.connect :latestadded, 'rest:///statistics/latest_added?:limit',
      :specific => 'rest:///statistics/added_timestamp/:project/:package'
    map.connect :latestupdated, 'rest:///statistics/latest_updated?:limit',
      :specific => 'rest:///statistics/updated_timestamp/:project/:package'
    map.connect :downloadcounter, 'rest:///statistics/download_counter' +
      '?:project&:package&:arch&:repo&:group_by&:limit'
    map.connect :rating, 'rest:///statistics/rating/:project/:package',
      :all => 'rest:///statistics/highest_rated?:limit'
    map.connect :mostactive, 'rest:///statistics/most_active?:type&:limit',
      :specific => 'rest:///statistics/activity/:project/:package'
    map.connect :globalcounters, 'rest:///statistics/global_counters',
      :all => 'rest:///statistics/global_counters'

    # Status Messages
    map.connect :statusmessage, 'rest:///status/messages/:id/?:limit'

    map.connect :distribution, "rest:///public/distributions",
      :all    => "rest:///public/distributions"

    map.connect :projectstatus, 'rest:///status/project/:project'

  end
  ActiveXML::Config.transport_for( :project ).set_additional_header( "User-Agent", "buildservice-webclient/#{CONFIG['version']}" )


end

