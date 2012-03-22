require 'delayed_job'
require File.join(Rails.root, 'lib/workers/issue_trackers_to_backend_job.rb')

class KernelIssueTrackerRegexp < ActiveRecord::Migration

  def self.up
    i = IssueTracker.find_by_name('bko')
    i.regex = '(?:Kernel|K|bko)#(\d+)'
    i.save
    Delayed::Job.enqueue IssueTrackersToBackendJob.new
  end

  def self.down
    i = IssueTracker.find_by_name('bko')
    i.regex = '(Kernel|K|bko)#(\d+)'
    i.save
    Delayed::Job.enqueue IssueTrackersToBackendJob.new
  end

end

