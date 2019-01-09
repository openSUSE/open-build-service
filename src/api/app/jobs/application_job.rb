class ApplicationJob < ActiveJob::Base
  before_perform :set_influxdb_tags

  private

  def set_influxdb_tags
    InfluxDB::Rails.current.tags = {
      beta: false,
      anonymous: true,
      interface: :job
    }
  end
end
