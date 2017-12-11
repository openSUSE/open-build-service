require File.dirname(__FILE__) + '/boot'
require File.dirname(__FILE__) + '/environment'

require 'clockwork'

module Clockwork
  every(17.seconds, 'fetch notifications', thread: true) do
    ActiveRecord::Base.connection_pool.with_connection do |_|
      # this will return if there is already a thread running
      UpdateNotificationEvents.new.perform
    end
  end

  every(30.seconds, 'status.refresh') do
    # this should be fast, so don't delay
    WorkerStatus.new.update_workerstatus_cache
  end

  every(30.seconds, 'send notifications') do
    SendEventEmailsJob.perform_later
  end

  every(49.minutes, 'rescale history') do
    StatusHistoryRescalerJob.perform_later
  end

  # Ensure that sphinx's searchd is running and reindex
  every(1.hour, 'reindex sphinx') do
    FullTextIndexJob.perform_later
  end

  every(1.hour, 'refresh issues') do
    IssueTracker.update_all_issues
  end

  every(1.hour, 'accept requests') do
    User.current = User.get_default_admin
    BsRequest.delayed_auto_accept
  end

  every(1.hour, 'cleanup notifications') do
    CleanupNotifications.perform_later
  end

  every(1.day, 'optimize history', thread: true, at: '05:00' ) do
    ActiveRecord::Base.connection_pool.with_connection do |sql|
      sql.execute 'optimize table status_histories;'
    end
  end

  every(1.day, 'refresh dirties', at: '23:00') do
    # inject a delayed job for every dirty project
    BackendPackage.refresh_dirty
  end

  every(1.day, 'clean old events', at: '00:00') do
    CleanupEvents.perform_later
  end

  every(1.day, 'create cleanup requests', at: '06:00' ) do
    User.current = User.get_default_admin
    ProjectCreateAutoCleanupRequests.perform_later
  end

  # check for new breakages between api and backend due to dull code
  every(1.week, 'consistency check', at: 'Sunday 03:00') do
    ConsistencyCheckJob.perform_later
  end
end
