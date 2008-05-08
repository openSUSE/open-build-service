class AddDevelProject < ActiveRecord::Migration
  def self.up
    add_column :db_packages, :develproject_id, :integer
    add_index :db_packages, [:develproject_id], :name => "devel_project_id_index"
  end

  def self.down
    remove_column :db_packages, :develproject_id
  end
end
