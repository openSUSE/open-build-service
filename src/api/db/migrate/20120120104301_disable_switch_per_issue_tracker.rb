class DisableSwitchPerIssueTracker < ActiveRecord::Migration
  def self.up
    add_column :issue_trackers, :enable_fetch, :bool, :default => false
    t = IssueTracker.find_by_name("bnc")
    t.enable_fetch=true
    t.save
  end

  def self.down
    remove_column :issue_trackers, :enable_fetch
  end
end
