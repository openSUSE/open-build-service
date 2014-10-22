class AddRequestPriority < ActiveRecord::Migration
  def self.up
    execute("alter table bs_requests add column `priority` enum('critical','important','moderate','low') DEFAULT 'moderate';")
  end

  def self.down
    remove_column :bs_requests, :priority, :integer
  end
end
