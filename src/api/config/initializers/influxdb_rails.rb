# If there are no hosts configured, disable this environment.
if CONFIG['influxdb_hosts'].blank?
  InfluxDB::Rails.configure do |config|
    config.ignored_environments << Rails.env
  end
  return
end
InfluxDB::Rails.configure do |config|
  config.client.database       = CONFIG['influxdb_database'] || 'performance'
  config.client.username       = CONFIG['influxdb_username'] || 'root'
  config.client.password       = CONFIG['influxdb_password'] || 'root'
  config.client.hosts          = CONFIG['influxdb_hosts']
  config.client.port           = CONFIG['influxdb_port'] || '8086'
  config.client.retry          = CONFIG['influxdb_retry'] || false
  config.client.use_ssl        = CONFIG['influxdb_ssl'] || false
  config.client.time_precision = CONFIG['influxdb_time_precision'] || 's'
end
