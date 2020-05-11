if CONFIG['influxdb_hosts'].blank? # defaults to localhost otherwise
  InfluxDB::Rails.configure do |config|
    config.instrumentation_enabled = false
  end
  return
end
InfluxDB::Rails.configure do |config|
  config.client.database       = CONFIG['influxdb_database'] || 'rails'
  config.client.username       = CONFIG['influxdb_username'] || 'root'
  config.client.password       = CONFIG['influxdb_password'] || 'root'
  config.client.hosts          = CONFIG['influxdb_hosts']
  config.client.port           = CONFIG['influxdb_port'] || '8086'
  config.client.retry          = CONFIG['influxdb_retry'] || false
  config.client.use_ssl        = CONFIG['influxdb_ssl'] || false
  config.client.time_precision = CONFIG['influxdb_time_precision'] || 's'
end
