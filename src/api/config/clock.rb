require "#{File.dirname(__FILE__)}/boot"
require "#{File.dirname(__FILE__)}/environment"

require 'clockwork'

module Clockwork
  error_handler do |error|
    Airbrake.notify(error)
  end

  on(:before_run) do |event|
    InfluxDB::Rails.current.tags = {
      interface: :clock,
      location: event.to_s
    }
  end

  every(17.seconds, 'fetch notifications', thread: true) do
    ActiveRecord::Base.connection_pool.with_connection do |_|
      # this will return if there is already a thread running
      UpdateNotificationEvents.new.perform
    end
  end

  every(30.seconds, 'refresh workerstatus') do
    Rails.cache.write('workerstatus', Backend::Api::BuildResults::Worker.status)
    # this should be fast, so don't delay
    WorkerStatus.new.save
  end

  every(30.seconds, 'send notifications') do
    SendEventEmailsJob.perform_later
  end

  every(5.minutes, 'send measurements') do
    MeasurementsJob.perform_later
    WorkerMeasurementsJob.perform_later
  end

  every(49.minutes, 'rescale history') do
    StatusHistoryRescalerJob.perform_later
  end

  every(1.hour, 'refresh issues') do
    IssueTracker.update_all_issues
  end

  every(1.hour, 'accept requests') do
    User.session = User.default_admin
    BsRequest.delayed_auto_accept
  end

  every(1.hour, 'refresh remote distros') do
    FetchRemoteDistributionsJob.perform_later
  end

  every(1.day, 'optimize history', thread: true, at: '05:00') do
    ActiveRecord::Base.connection_pool.with_connection do |sql|
      sql.execute('optimize table status_histories;')
    end
  end

  every(1.day, 'refresh dirties', at: '23:00') do
    # inject a delayed job for every dirty project
    BackendPackage.refresh_dirty
  end

  every(1.day, 'clean old events', at: '00:00') do
    CleanupEvents.perform_later
  end

  every(1.day, 'clean old project log entries', at: '02:30') do
    CleanupProjectLogEntries.perform_later
  end

  every(1.day, 'cleanup notifications') do
    CleanupNotificationsJob.perform_later
  end

  every(1.day, 'create cleanup requests', at: '06:00') do
    User.session = User.default_admin
    ProjectCreateAutoCleanupRequestsJob.perform_later
  end

  every(1.day, 'daily user activity measurements') do
    DailyUserActivityMeasurementJob.perform_later
  end

  # check for new breakages between api and backend due to dull code
  every(1.week, 'consistency check', at: 'Sunday 03:00') do
    Old::ConsistencyCheckJob.perform_later
  end

  # Expire assignments after 24h
  every(1.day, 'expire assignments') do
    ExpireAssignmentsJob.perform_later
  end
end
