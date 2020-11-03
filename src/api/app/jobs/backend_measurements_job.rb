class BackendMeasurementsJob < ApplicationJob
  queue_as :quick

  def perform
    return unless CONFIG['amqp_options']

    RabbitmqBus.send_to_bus('metrics', "workers #{worker_status_fields}")

    worker_jobs = WorkerStatusService::JobsStatisticsFetcher.call
    worker_jobs[:waiting].each do |wj|
      RabbitmqBus.send_to_bus('metrics', "waiting_jobs,#{jobs_fields(wj)}")
    end
    worker_jobs[:blocked].each do |wj|
      RabbitmqBus.send_to_bus('metrics', "blocked_jobs,#{jobs_fields(wj)}")
    end
  end

  private

  def worker_status_fields
    WorkerStatus.statistics.map { |k, v| "#{k}=#{v}" }.join(',')
  end

  def jobs_fields(job_line)
    job_line.map { |k, v| "#{k}=#{v}" }.join(' ')
  end
end
