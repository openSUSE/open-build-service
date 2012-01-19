class SetCurrentTimeAsUpdated < ActiveRecord::Migration
  def self.up
    IssueTracker.find(:all).each do |t|
      t.issues_updated=Time.now unless t.issues_updated
      t.save
    end
  end

  def self.down
  end
end
