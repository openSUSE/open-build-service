class AddRequestPriority < ActiveRecord::Migration
  def self.up
    add_column :bs_requests, :priority, :integer, default: "moderate"

    execute("alter table bs_requests modify column `priority` enum('critical','important','moderate','low') DEFAULT 'moderate';")
    execute("UPDATE bs_requests SET priority = 'moderate' WHERE ISNULL(priority);")
  end

  def self.down
    remove_column :bs_requests, :priority, :integer
  end
end
