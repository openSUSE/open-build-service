class AddDevelPackage < ActiveRecord::Migration
  def self.up
    add_column :db_packages, :develpackage_id, :integer
    add_index :db_packages, [:develpackage_id], :name => "devel_package_id_index"
  end

  def self.down
    remove_column :db_packages, :develpackage_id
  end
end
