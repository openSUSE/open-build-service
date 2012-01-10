class IssueStateEnum < ActiveRecord::Migration
  def self.up
    remove_column :issues, :state
    add_column :issues, :state,  :integer
    execute "alter table issues modify column state enum('OPEN','CLOSED','UNKNOWN');"
  end

  def self.down
    remove_column :issues, :state
    add_column :issues, :state
  end
end
