class DisableAllIssueTrackers < ActiveRecord::Migration
  def self.up
    # all but bnc were disabled already
    t = IssueTracker.find_by_name("bnc")
    t.enable_fetch=false
    t.save
  end

  def self.down
    t = IssueTracker.find_by_name("bnc")
    t.enable_fetch=true
    t.save
  end
end
