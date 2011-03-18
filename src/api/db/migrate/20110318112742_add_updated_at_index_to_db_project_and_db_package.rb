class AddUpdatedAtIndexToDbProjectAndDbPackage < ActiveRecord::Migration
  def self.up
    add_index :db_projects, :updated_at, :name => "updated_at_index"
    add_index :db_packages, :updated_at, :name => "updated_at_index"
  end

  def self.down
    remove_index :db_projects, :updated_at
    remove_index :db_packages, :updated_at
  end
end
