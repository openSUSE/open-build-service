return if CONFIG['influxdb_hosts'].blank? # defaults to localhost otherwise

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
end
