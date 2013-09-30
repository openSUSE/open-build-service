class FateIssueTrackerFix < ActiveRecord::Migration
  def up
    t=IssueTracker.find_by_name('fate')
    t.regex='Fate|fate|FATE\s*#\s*(\d+)'
    t.save
    Delayed::Job.enqueue IssueTrackersToBackendJob.new
  end

  def down
    t=IssueTracker.find_by_name('fate')
    t.regex='[Ff]ate\s+#\s+(\d+)'
    t.save
    Delayed::Job.enqueue IssueTrackersToBackendJob.new
  end
end
