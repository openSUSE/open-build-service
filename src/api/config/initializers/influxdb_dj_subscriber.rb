ActiveSupport::Notifications.subscribe('perform.active_job') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  job = event.payload[:job]
  InfluxDB::Rails.client.write_point('active_job.performance',
                                     tags: { job: job.class.name, queue: job.queue_name },
                                     values: { value: event.duration })
end
