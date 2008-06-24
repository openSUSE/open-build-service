class AddCreateAndModifiedTimeStamps < ActiveRecord::Migration
  def self.up
    add_column :db_projects, :created_at, :datetime, :default => '2005-01-01 00:00:01'
    add_column :db_projects, :updated_at, :datetime, :default => '2005-01-01 00:00:01'
    add_column :db_packages, :created_at, :datetime, :default => '2005-01-01 00:00:02'
    add_column :db_packages, :updated_at, :datetime, :default => '2005-01-01 00:00:02'
  end

  def self.down
    remove_column :db_projects, :created_at
    remove_column :db_projects, :updated_at
    remove_column :db_packages, :created_at
    remove_column :db_packages, :updated_at
  end
end
