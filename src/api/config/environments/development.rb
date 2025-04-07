require "active_support/core_ext/integer/time"

OBSApi::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Server timing middleware (https://github.com/rails/rails/pull/36289)
  config.server_timing = true

  # Eager load sub-classes we use in associations
  # (ack class_name app/models |ack ::)
  # so we don't face "uninitalized constant Something" errors.
  sti_classes_to_eager_load = Dir["app/models/status/**.rb",
                                  "app/models/history_element/**.rb",
                                  "app/models/token.rb",
                                  "app/models/token/**.rb"]
  config.eager_load_paths += sti_classes_to_eager_load
  ActiveSupport::Reloader.to_prepare do
    sti_classes_to_eager_load.each { |f| require_dependency("#{Dir.pwd}/#{f}") }
  end

  # see http://guides.rubyonrails.org/action_mailer_basics.html#example-action-mailer-configuration
  config.action_mailer.delivery_method = :test
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false

  # Show full error reports and enable caching
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = true

  # Use memcache for cache/session storage
  config.cache_store = if CONFIG['memcached_host']
                         [:mem_cache_store, CONFIG['memcached_host']]
                       else
                         :mem_cache_store
                       end
  config.session_store :cache_store

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.logger = nil

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Enable debug logging by default
  config.log_level = :debug
  config.secret_key_base = '92b2ed725cb4d68cc5fbf86d6ba204f1dec4172086ee7eac8f083fb62ef34057f1b770e0722ade7b298837be7399c6152938627e7d15aca5fcda7a4faef91fc7'

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Bullet configuration
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.add_footer = true
  end

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true
end

CONFIG['extended_backend_log'] = true
CONFIG['response_schema_validation'] = true

CONFIG['frontend_host'] = 'localhost'
CONFIG['frontend_protocol'] = 'http'

# Display fake sponsors above the footer on every page
CONFIG['sponsors'] = [
  ActiveSupport::HashWithIndifferentAccess.new(
    name: 'Greens Food Supplies',
    description: 'Direct delivery service',
    icon: 'sponsor_greens-food-supplies',
    url: '#'
  ),
  ActiveSupport::HashWithIndifferentAccess.new(
    name: 'Auto Speed',
    description: 'Same day auto parts',
    icon: 'sponsor_auto-speed',
    url: '#'
  )
]
