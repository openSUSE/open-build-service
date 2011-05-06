class AddMaintenanceProjectIdToDbProject  < ActiveRecord::Migration
  def self.up
    add_column :db_projects, :maintenance_project_id, :int, :null => true
  end

  def self.down
    remove_column :db_projects, :maintenance_project_id
  end
end
