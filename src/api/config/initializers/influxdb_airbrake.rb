# send exceptions to Influxdb

module Airbrake
  class << self
    def notify(exception, params = {}, &block)
      notice_notifier.notify(exception, params, &block)
      InfluxDB::Rails.client.write_point('rails.exceptions', values: { value: 1, error_class: exception.class.to_s }) if CONFIG['influxdb_hosts'].present?
    end
  end
end
