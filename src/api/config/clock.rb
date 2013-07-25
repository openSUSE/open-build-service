require File.dirname(__FILE__) + '/boot'
require File.dirname(__FILE__) + '/environment'

require 'clockwork'
include Clockwork

every(30.seconds, 'status.refresh') do
  Rails.logger.debug "Refresh worker status"
  c = StatusController.new
  # this should be fast, so don't delay
  c.update_workerstatus_cache
end
 
every(1.hour, 'refresh issues') do
  IssueTracker.all.each do |t|
    next unless t.enable_fetch
    t.delay.update_issues
  end
end

every(49.minutes, 'rescale history') do
  # we just pick the first to have a model to .delay
  StatusHistory.first.delay.rescale
end

every(1.day, 'optimize history', thread: true) do
  sql = ActiveRecord::Base.connection
  sql.execute "optimize table status_histories;"
end

every(5.minutes, 'check last events') do
  bi = BackendInfo.first
  # save *something* to have a model we can delay on
  BackendInfo.lastevents_nr = 1 unless bi
  BackendInfo.first.delay.update_last_events 
end

