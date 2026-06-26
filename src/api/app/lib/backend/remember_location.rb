module Backend
  module RememberLocation
    def singleton_method_added(method_name)
      return if filtering.include?(method_name)
      return if method_name == :singleton_method_added
      return if method_name == :initialize

      original_method = singleton_method(method_name)

      filtering << method_name

      define_singleton_method(method_name) do |*args, **kwargs, &block|
        Thread.current[:_influxdb_obs_backend_api_method] = method_name.to_s
        Thread.current[:_influxdb_obs_backend_api_module] = name
        original_method.call(*args, **kwargs, &block)
      ensure
        Thread.current[:_influxdb_obs_backend_api_method] = nil
        Thread.current[:_influxdb_obs_backend_api_module] = nil
      end
    end

    private

    def filtering
      @filtering ||= []
    end
  end
end
