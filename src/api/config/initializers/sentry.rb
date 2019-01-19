Raven.configure do |config|
  config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)
  config.dsn = CONFIG['sentry_dsn'] || ENV['SENTRY_DSN']
end
