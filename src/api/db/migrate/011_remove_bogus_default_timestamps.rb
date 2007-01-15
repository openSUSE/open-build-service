class RemoveBogusDefaultTimestamps < ActiveRecord::Migration
  def self.up
    change_column :db_projects, :created_at, :datetime, :default => 0
    change_column :db_projects, :updated_at, :datetime, :default => 0
    change_column :db_packages, :created_at, :datetime, :default => 0
    change_column :db_packages, :updated_at, :datetime, :default => 0
  end

  def self.down
    change_column :db_projects, :created_at, :datetime, :default => '2005-01-01 00:00:01'
    change_column :db_projects, :updated_at, :datetime, :default => '2005-01-01 00:00:01'
    change_column :db_packages, :created_at, :datetime, :default => '2005-01-01 00:00:02'
    change_column :db_packages, :updated_at, :datetime, :default => '2005-01-01 00:00:02'
  end
end
