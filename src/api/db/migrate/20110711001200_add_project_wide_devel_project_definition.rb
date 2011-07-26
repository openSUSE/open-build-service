class AddProjectWideDevelProjectDefinition < ActiveRecord::Migration
  def self.up
    add_column :db_projects, :develproject_id, :integer
    add_index :db_projects, [:develproject_id], :name => "devel_project_id_index"
  end

  def self.down
    remove_column :db_projects, :develproject_id
  end
end
