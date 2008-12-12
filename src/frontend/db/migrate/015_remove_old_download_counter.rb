class RemoveOldDownloadCounter < ActiveRecord::Migration


  def self.up
    remove_column :db_packages, :downloads
  end


  def self.down
    add_column :db_packages, :downloads, :integer, :default => 0
  end


end
