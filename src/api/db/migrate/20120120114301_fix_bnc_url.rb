class FixBncUrl < ActiveRecord::Migration
  def self.up
    t=IssueTracker.find_by_name('bnc')
    t.url="https://apibugzilla.novell.com"
    t.save
    Delayed::Job.enqueue IssueTrackersToBackendJob.new
  end

  def self.down
    t=IssueTracker.find_by_name('bnc')
    t.url="https://bugzilla.novell.com"
    t.save
    Delayed::Job.enqueue IssueTrackersToBackendJob.new
  end
end
