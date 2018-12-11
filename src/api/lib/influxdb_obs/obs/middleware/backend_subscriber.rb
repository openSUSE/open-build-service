require 'logger'

module InfluxDB
  module OBS
    module Middleware
      class BackendSubscriber
        def initialize(series_name, logger = Logger.new(STDOUT))
          @series_name = series_name
          @logger = logger
        end

        def call(_name, _started, finished, _unique_id, data)
          return unless enabled?

          InfluxDB::Rails.client.write_point(series_name,
                                             tags: tags(data),
                                             values: values(data[:runtime]),
                                             timestamp: timestamp(finished))
        rescue StandardError => e
          logger.info "[InfluxDB Backend Subscriber]: #{e.message}"
        end

        private

        attr_reader :series_name, :logger

        def timestamp(time)
          InfluxDB.convert_timestamp(time, InfluxDB::Rails.configuration.time_precision)
        end

        def enabled?
          CONFIG['influxdb_hosts'].present?
        end

        def values(runtime)
          { value: ((runtime || 0) * 1000).ceil }
        end

        def tags(data)
          {
            http_method: data[:http_method],
            http_status_code: data[:http_status_code],
            host: data[:host],
            controller_location: data[:controller_location],
            backend_location: data[:backend_location]
          }.reject { |_, value| value.blank? }
        end
      end
    end
  end
end
