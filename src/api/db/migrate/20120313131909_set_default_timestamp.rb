class SetDefaultTimestamp < ActiveRecord::Migration
  def self.up
    change_column :issue_trackers, :issues_updated, :timestamp, :null => false
    execute "ALTER TABLE `issue_trackers` ALTER `issues_updated` DROP DEFAULT"
  end

  def self.down
    change_column :issue_trackers, :issues_updated, :timestamp, :default => Time.now
  end
end
