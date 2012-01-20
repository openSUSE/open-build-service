class AddUpdateTimestamp < ActiveRecord::Migration
  def self.up
    add_column :issue_trackers, :issues_updated, :timestamp, :default => Time.now
  end

  def self.down
    remove_column :issue_trackers, :issues_updated
  end
end
