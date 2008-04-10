class AddRemoteBsConfig < ActiveRecord::Migration
  def self.up
    add_column :db_projects, :remoteurl, :string
    add_column :db_projects, :remoteproject, :string
  end

  def self.down
    remove_column :db_projects, :remoteurl
    remove_column :db_projects, :remoteproject
  end
end
