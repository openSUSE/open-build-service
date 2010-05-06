class AddProjidIndex < ActiveRecord::Migration
  def self.up
    add_index :db_packages, :db_project_id
  end

  def self.down
    remove_index :db_packages, :db_project_id
  end
end
