class AddIndexForMaintenance < ActiveRecord::Migration
  def self.up
    add_index :db_projects, :maintenance_project_id
  end

  def self.down
    remove_index :db_projects, :maintenance_project_id
  end
end
