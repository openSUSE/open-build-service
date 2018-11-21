InfluxDB::Rails.configure do |config|
  config.influxdb_database = CONFIG['influxdb_database']
  config.influxdb_username = CONFIG['influxdb_username']
  config.influxdb_password = CONFIG['influxdb_password']
  config.influxdb_hosts    = CONFIG['influxdb_hosts'] || [] # default is otherwise localhost
  config.influxdb_port     = CONFIG['influxdb_port']
  config.retry             = CONFIG['influxdb_retry']
  config.use_ssl           = CONFIG['influxdb_ssl']
end
