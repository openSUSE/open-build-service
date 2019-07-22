# typed: strict
require_relative '../../lib/influxdb_obs/obs/middleware/backend_subscriber'

ActiveSupport::Notifications.subscribe('obs.backend.process_response', InfluxDB::OBS::Middleware::BackendSubscriber.new('rails.backend', Rails.logger))
