class UpdateIssueTrackersInBackend < ActiveRecord::Migration

  def self.up
    IssueTracker.write_to_backend
  end

  def self.down
  end

end

