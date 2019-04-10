class InstrumentationDelayedJobQueue < ApplicationJob
  def perform
    InfluxDB::Rails.client.write_point('active_job.queue',
                                       tags: { state: :failed },
                                       values: { value: failed_count })
    InfluxDB::Rails.client.write_point('active_job.queue',
                                       tags: { state: :in_process },
                                       values: { value: in_process_count })
    InfluxDB::Rails.client.write_point('active_job.queue',
                                       tags: { state: :retrying },
                                       values: { value: retrying_count })
    InfluxDB::Rails.client.write_point('active_job.queue',
                                       tags: { state: :queued },
                                       values: { value: queued_count })
  end

  private

  def failed_count
    Delayed::Job.where.not(failed_at: nil).count
  end

  def in_process_count
    Delayed::Job.where.not(failed_at: nil).where('locked_at > ?', Time.zone.now - Delayed::Worker.max_run_time).count
  end

  def retrying_count
    Delayed::Job.where.not(failed_at: nil).where('attempts > 0').count
  end

  def queued_count
    Delayed::Job.where('run_at <= NOW()')
                .where('attempts = 0')
                .where.not(locked_at: nil)
                .where.not(locked_by: nil)
                .where.not(failed_at: nil)
                .count
  end
end
