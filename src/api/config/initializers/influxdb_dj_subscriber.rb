# typed: true
if CONFIG['influxdb_hosts']
  ActiveSupport::Notifications.subscribe(/active_job/) do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]
    exception = event.payload[:exception_object]

    def write_queue_stats(state, job)
      InfluxDB::Rails.client.write_point('active_job.queue',
                                         tags: { state: state, job: job.class.name, queue: job.queue_name },
                                         values: { value: 1 })
    end

    def write_performance_stats(job, event)
      InfluxDB::Rails.client.write_point('active_job.performance',
                                         tags: { job: job.class.name, queue: job.queue_name },
                                         values: { value: event.duration })
    end

    if event.name == 'perform.active_job' && exception
      InfluxDB::Rails.client.write_point('active_job.queue',
                                         tags: { state: :failed, job: job.class.name, queue: job.queue_name },
                                         values: { value: 1, id: job.job_id })
      next
    end

    case event.name
    when 'enqueue.active_job'
      write_queue_stats(:queued, job)
    when 'perform_start.active_job'
      write_queue_stats(:running, job)
    when 'perform.active_job'
      write_queue_stats(:succeeded, job)
      write_performance_stats(job, event)
    end
  end
end
