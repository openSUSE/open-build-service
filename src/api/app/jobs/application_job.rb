class ApplicationJob < ActiveJob::Base
  before_perform :set_influxdb_tags

  private

  def set_influxdb_tags
    InfluxDB::Rails.current.tags = {
      interface: :job,
      location: self.class.name
    }
  end
end
