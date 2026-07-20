require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV.fetch("RAILS_SERVE_STATIC_FILES", false)

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = CONFIG['assume_ssl']

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = CONFIG['force_ssl']

  # Log the current request id as a default log tag.
  config.log_tags = [ :request_id ]

  # Use lograge to show the logs in one line
  config.lograge.enabled = true
  config.lograge.custom_options = lambda do |event|
    exceptions = %w[controller action format id]
    {
      params: event.payload[:params].except(*exceptions),
      host: event.payload[:headers].env['HTTP_X_FORWARDED_FOR']&.split(',')&.first || event.payload[:headers].env['REMOTE_ADDR'],
      backend: event.payload[:backend_runtime],
      user: User.possibly_nobody
    }
  end
  config.lograge.custom_payload do |controller|
    {
      bot: controller.request.bot?
    }
  end

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = if CONFIG['memcached_host']
                         [:mem_cache_store, CONFIG['memcached_host']]
                       else
                         :mem_cache_store
                       end

  # Store the sessions in memcached too
  config.session_store :cache_store

  # Turn off live Sprockets compilation
  config.assets.compile = false
  # Use terser as javascript compressor
  # https://github.com/terser/terser
  config.assets.js_compressor = :terser

  # Use DelayedJob gem as qeuing backend for Active Job
  config.active_job.queue_adapter = :delayed_job

  # see http://guides.rubyonrails.org/action_mailer_basics.html#example-action-mailer-configuration
  config.action_mailer.delivery_method = :sendmail
  config.action_mailer.perform_caching = false

  # compress our HTML
  config.middleware.use(Rack::Deflater)

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]
end

# ActiveJob already logs everything we need
Delayed::Worker.default_log_level = 'debug'
