class FixCveRegexp < ActiveRecord::Migration
  def self.up
    t=IssueTracker.find_by_name('cve')
    t.regex="(CVE-\d{4,4}-\d{4,4})"
    t.save
    Delayed::Job.enqueue IssueTrackersToBackendJob.new
  end

  def self.down
    t=IssueTracker.find_by_name('cve')
    t.regex="CVE-\d{4,4}-\d{4,4}"
    t.save
    Delayed::Job.enqueue IssueTrackersToBackendJob.new
  end
end
