# Drop created_at and updated_at timestamps for tables where they
# don't add real value.

class DropMultipleUnneededTimestampRows < ActiveRecord::Migration
  def self.up
    remove_column :delayed_jobs, :created_at
    remove_column :delayed_jobs, :updated_at
    remove_column :roles, :created_at
    remove_column :roles, :updated_at
    remove_column :roles_static_permissions, :created_at
    remove_column :static_permissions, :created_at
    remove_column :static_permissions, :updated_at
    remove_column :taggings, :created_at
  end

  def self.down
    add_column :delayed_jobs, :created_at, :timestamp
    add_column :delayed_jobs, :updated_at, :timestamp
    add_column :roles, :created_at, :timestamp
    add_column :roles, :updated_at, :timestamp
    add_column :roles_static_permissions, :created_at, :timestamp
    add_column :static_permissions, :created_at, :timestamp
    add_column :static_permissions, :updated_at, :timestamp
    add_column :taggings, :created_at, :timestamps
  end
end
