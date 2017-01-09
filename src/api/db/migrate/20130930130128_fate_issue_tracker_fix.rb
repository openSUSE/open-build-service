class FateIssueTrackerFix < ActiveRecord::Migration
  def up
    t = IssueTracker.find_by_name('fate')
    t.regex = '(?:fate|Fate|FATE)\s*#\s*(\d+)'
    t.save
    Delayed::Worker.delay_jobs = true
    IssueTracker.write_to_backend
  end

  def down
    t = IssueTracker.find_by_name('fate')
    t.regex = '[Ff]ate\s+#\s+(\d+)'
    t.save
    Delayed::Worker.delay_jobs = true
    IssueTracker.write_to_backend
  end
end
