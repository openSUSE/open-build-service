module Backend
  class Instrumentation
    def initialize(http_method, host, http_status_code, runtime)
      @http_method = http_method
      @host = host
      @http_status_code = http_status_code
      @runtime = runtime || 0
    end

    def instrument
      InfluxDB::Rails.instrument('connection.obs_backend', tags: tags, values: values)
    end

    private

    attr_accessor :http_method, :host, :http_status_code, :runtime

    def tags
      {
        hook: 'obs_backend',
        http_method: http_method,
        http_status_code: http_status_code,
        host: host,
        backend_location: backend_location
      }
    end

    def values
      {
        value: (runtime * 1000).ceil
      }
    end

    def backend_location
      result = [
        Thread.current[:_influxdb_obs_backend_api_module],
        Thread.current[:_influxdb_obs_backend_api_method]
      ].reject(&:blank?)
      result.empty? ? :raw : result.join('#')
    end
  end
end
