require 'singleton'

class PrometheusRegistry
  include Singleton

  def initialize
    @prometheus_client = Prometheus::Client.registry
  end

  def self.[](_key)
    Prometheus::Client::Counter.new(:obs_user_login, "Counter for OBS logins")
  end

  def register(metric)
    @prometheus_client.register(metric)
  rescue Prometheus::Client::Registry::AlreadyRegisteredError
    # FIXME
  end
end
