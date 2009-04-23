class ModifyRepositoryForRemoteBs < ActiveRecord::Migration
  def self.up
    remove_index :repositories, :name => "projects_name_index"
    add_column :repositories, :remote_project_name, :string
    add_index :repositories, [:db_project_id, :name, :remote_project_name], :name => "projects_name_index", :unique =>true
    add_index :repositories, :remote_project_name, :name => "remote_project_name_index"
  end

  def self.down
    remove_index :repositories, :name => "projects_name_index"
    remove_index :repositories, :name => "remote_project_name_index"
    remove_column :repositories, :remote_project_name
    add_index :repositories, [:db_project_id, :name], :name => "projects_name_index", :unique => true
  end
end
