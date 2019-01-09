module Backend
  class Instrumentation
    def initialize(http_method, host, http_status_code, runtime)
      @http_method = http_method
      @host = host
      @http_status_code = http_status_code
      @runtime = runtime
    end

    def instrument
      return unless enabled?

      ActiveSupport::Notifications.instrument('obs.backend.process_response', data)
      reset_backend_location
    end

    private

    attr_accessor :http_method, :host, :http_status_code, :runtime

    def enabled?
      CONFIG['influxdb_hosts'].present?
    end

    def data
      {
        http_method: http_method,
        http_status_code: http_status_code,
        host: host,
        runtime: runtime,
        controller_location: controller_location,
        backend_location: backend_location
      }
    end

    def controller_location
      [
        Thread.current[:_influxdb_rails_controller],
        Thread.current[:_influxdb_rails_action]
      ].reject(&:blank?).join('#')
    end

    def backend_location
      result = [
        Thread.current[:_influxdb_obs_backend_api_module],
        Thread.current[:_influxdb_obs_backend_api_method]
      ]
      result.empty? ? 'RAW' : result.join('#')
    end

    def reset_backend_location
      Thread.current[:_influxdb_obs_backend_api_module] = nil
      Thread.current[:_influxdb_obs_backend_api_method] = nil
    end
  end
end
