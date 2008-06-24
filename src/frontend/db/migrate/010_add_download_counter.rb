class AddDownloadCounter < ActiveRecord::Migration


  def self.up
    add_column :db_packages, :downloads, :integer, :default => 0
  end


  def self.down
    remove_column :db_packages, :downloads
  end


end
