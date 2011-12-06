class KernelIssueTrackerRegexp < ActiveRecord::Migration

  def self.up
    i = IssueTracker.find_by_name('bko')
    i.regex = '(?:Kernel|K|bko)#(\d+)'
    i.save
    IssueTracker.write_to_backend
  end

  def self.down
    i = IssueTracker.find_by_name('bko')
    i.regex = '(Kernel|K|bko)#(\d+)'
    i.save
    IssueTracker.write_to_backend
  end

end

