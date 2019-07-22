# typed: strict
if CONFIG['influxdb_hosts'].blank? # defaults to localhost otherwise
  InfluxDB::Rails.configure do |config|
    config.instrumentation_enabled = false
  end
  return
end
InfluxDB::Rails.configure do |config|
  config.influxdb_database   = CONFIG['influxdb_database']
  config.influxdb_username   = CONFIG['influxdb_username']
  config.influxdb_password   = CONFIG['influxdb_password']
  config.influxdb_hosts      = CONFIG['influxdb_hosts']
  config.influxdb_port       = CONFIG['influxdb_port']
  config.retry               = CONFIG['influxdb_retry'] || false # default is infinite otherwise
  config.use_ssl             = CONFIG['influxdb_ssl']
  config.time_precision      = CONFIG['influxdb_time_precision']
  config.series_name_for_sql = 'rails.sql'
  config.tags_middleware = lambda do |tags|
    result = { beta: false, anonymous: true, interface: :none }.merge!(tags)
    # TODO: workaround for https://github.com/influxdata/influxdb-rails/pull/64
    result.reject! { |_, value| value.nil? || value == '' }
    return result if result.key?(:method)

    # set the default location for e.g. SQL calls outside a request
    { location: :raw }.merge!(result)
  end
end
