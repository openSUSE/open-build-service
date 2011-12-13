
class AddUserAndPasswordToIssueTracker < ActiveRecord::Migration
  def self.up
    add_column :issue_trackers, :user, :string
    add_column :issue_trackers, :password, :string
  end

  def self.down
    change_table :issue_trackers do |t|
      t.remove :user
      t.remove :password
    end
  end
end
