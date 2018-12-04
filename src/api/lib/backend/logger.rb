require_relative '../influxdb_obs/obs/normalizer/location_normalizer'

module Backend
  # Class that implements a logger to write output in the backend logs
  class Logger
    @backend_logger = ::Logger.new("#{Rails.root}/log/backend_access.log")
    @backend_time = 0

    def self.reset_runtime
      @backend_time = 0
    end

    def self.runtime
      @backend_time
    end

    def self.info(method, host, port, path, response, start_time)
      time_delta = Time.now - start_time
      now = Time.now.strftime '%Y%m%dT%H%M%S'
      @backend_logger.info "#{now} #{method} #{host}:#{port}#{path} #{response.code} #{time_delta}"
      @backend_time += time_delta
      Rails.logger.debug "request took #{time_delta} #{@backend_time}"
      instrument_notification(method, host, response.code, time_delta)

      return unless CONFIG['extended_backend_log']

      data = response.body
      if data.nil?
        @backend_logger.info '(no data)'
      elsif data.class == 'String' && data[0, 1] == '<'
        @backend_logger.info data
      else
        @backend_logger.info "(non-XML data) #{data.class}"
      end
    end

    def self.instrument_notification(method, host, code, runtime)
      return if CONFIG['influxdb_hosts'].blank?

      location = InfluxDB::OBS::Normalizer::LocationNormalizer.new(caller_locations(4, 8))
      data = {
        http_method: method,
        http_status: code,
        host: host,
        runtime: runtime,
        controller: location.controller_name,
        backend: location.backend_name
      }
      ActiveSupport::Notifications.instrument('obs.backend.process_response', data)
    end
  end
end
