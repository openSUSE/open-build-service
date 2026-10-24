# frozen_string_literal: true

# Jobs that were enqueued in the 'quick' queue before their classes were moved
# to other queues would otherwise stay in the 'quick' queue. Move them to the
# queue their class uses now, so they get processed by the right workers.
class MoveJobsOutOfQuickQueue < ActiveRecord::Migration[8.1]
  JOB_QUEUES = {
    'UpdatePackagesIfDirtyJob' => 'quick_user',
    'BsRequestActionWebuiInfosJob' => 'quick_user',
    'SyncLocalPackageVersionJob' => 'slow_user',
    'CreateLocalPackageVersionJob' => 'slow_user',
    'SyncUpstreamPackageVersionJob' => 'slow_user',
    'PopulateToSphinxJob' => 'slow_user',
    'DeleteFromSphinxJob' => 'slow_user',
    'ProjectDoProjectCopyJob' => 'slow_user',
    'ProjectDoProjectReleaseJob' => 'slow_user',
    'StatusHistoryRescalerJob' => 'slow_user',
    'ConfigurationWriteToBackendJob' => 'internal',
    'IssueTrackerWriteToBackendJob' => 'internal',
    'WorkerMeasurementsJob' => 'internal',
    'MeasurementsJob' => 'internal',
    'DailyUserActivityMeasurementJob' => 'internal'
  }.freeze

  # rubocop:disable Rails/SkipsModelValidations
  def up
    JOB_QUEUES.each do |job_class, queue|
      jobs_in_quick_queue(job_class).update_all(queue: queue)
    end
  end

  def down
    JOB_QUEUES.each do |job_class, queue|
      Delayed::Job.where(queue: queue).where('handler LIKE ?', handler_pattern(job_class)).update_all(queue: 'quick')
    end
  end

  # rubocop:enable Rails/SkipsModelValidations

  private

  def jobs_in_quick_queue(job_class)
    Delayed::Job.where(queue: 'quick').where('handler LIKE ?', handler_pattern(job_class))
  end

  # The trailing newline avoids matching job classes sharing a prefix
  def handler_pattern(job_class)
    "%job_class: #{job_class}\n%"
  end
end
