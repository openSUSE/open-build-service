require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  # Run rails dev:cache to toggle Action Controller caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Use memcache for cache/session storage if configured, like we do on production
  config.cache_store = if CONFIG['memcached_host']
                         [:mem_cache_store, CONFIG['memcached_host']]
                       else
                         :mem_cache_store
                       end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # We do not care about email delivery in this environment
  config.action_mailer.perform_deliveries = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Append comments with runtime information tags to SQL queries in logs.
  config.active_record.query_log_tags_enabled = true

  # Use DelayedJob gem as queuing backend for Active Job
  config.active_job.queue_adapter = :delayed_job

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

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

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Disables the concatenation and compression of assets.
  config.assets.debug = true

  # Bullet configuration
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.add_footer = true
  end
end

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

