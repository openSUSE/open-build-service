class CreateIssueTrackers < ActiveRecord::Migration
  def self.up
    create_table :issue_trackers do |t|
      t.string :name, :null => false
      t.index :name
      t.string :url, :null => false
      t.string :show_url
    end

    create_table :issue_tracker_acronyms do |t|
      t.integer :issue_tracker_id
      t.string :name, :null => false
      t.index :name
    end
  end

  def self.down
    drop_table :issue_tracker_acronyms
    drop_table :issue_trackers
  end
end
