class CreateAdvancedDownloadStats < ActiveRecord::Migration


  def self.up
    create_table :download_stats do |t|
      t.column :db_project_id, :integer
      t.column :db_package_id, :integer
      t.column :repository_id, :integer
      t.column :architecture_id, :integer
      t.column :filename, :string
      t.column :filetype, :string, :limit => 10
      t.column :version, :string
      t.column :release, :string
      t.column :created_at, :timestamp
      t.column :counted_at, :timestamp
      t.column :count, :integer
    end
    add_index :download_stats, ['db_project_id'], :name => "project"
    add_index :download_stats, ['db_package_id'], :name => "package"
    add_index :download_stats, ['repository_id'], :name => "repository"
    add_index :download_stats, ['architecture_id'], :name => "arch"
  end


  def self.down
    drop_table :download_stats
  end


end
