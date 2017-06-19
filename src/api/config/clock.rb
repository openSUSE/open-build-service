require File.dirname(__FILE__) + '/boot'
require File.dirname(__FILE__) + '/environment'

# make sure our event is loaded first - the clockwork::event is *not* ours
require 'event'

require 'clockwork'

module Clockwork
  every(30.seconds, 'status.refresh') do
    # this should be fast, so don't delay
    WorkerStatus.new.update_workerstatus_cache
  end

  every(1.hour, 'refresh issues') do
    IssueTracker.update_all_issues
  end

  every(1.hour, 'accept requests') do
    User.current = User.get_default_admin
    BsRequest.delayed_auto_accept
  end

  every(49.minutes, 'rescale history') do
    StatusHistoryRescaler.new.delay.rescale
  end

  every(1.day, 'optimize history', thread: true) do
    ActiveRecord::Base.connection_pool.with_connection do |sql|
      sql.execute 'optimize table status_histories;'
    end
  end

  every(1.hour, 'cleanup notifications') do
    CleanupNotifications.perform_later
  end

  every(30.seconds, 'send notifications') do
    ::Event::NotifyBackends.trigger_delayed_sent
    SendEventEmails.new.delay.perform
  end

  every(17.seconds, 'fetch notifications', thread: true) do
    ActiveRecord::Base.connection_pool.with_connection do |_|
      # this will return if there is already a thread running
      UpdateNotificationEvents.new.perform
    end
  end

  # Ensure that sphinx's searchd is running and reindex
  every(1.hour, 'reindex sphinx') do
    FullTextSearch.new.delay.index_and_start unless Rails.env.test? || Rails.env.development?
  end

  every(1.day, 'refresh dirties') do
    # inject a delayed job for every dirty project
    BackendPackage.refresh_dirty
  end

  every(10.minutes, 'project log rotates') do
    ProjectLogRotate.new.delay.perform
  end

  every(1.day, 'clean old events') do
    CleanupEvents.perform_later
  end

  every(1.day, 'create cleanup requests') do
    User.current = User.get_default_admin
    ProjectCreateAutoCleanupRequests.perform_later
  end

  # check for new breakages between api and backend due to dull code
  every(1.week, 'consistency check') do
    ConsistencyCheckJob.new.delay.perform
  end
end
