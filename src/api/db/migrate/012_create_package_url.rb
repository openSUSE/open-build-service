class CreatePackageUrl < ActiveRecord::Migration


  def self.up
    add_column :db_packages, :url, :string
  end


  def self.down
    remove_column :db_packages, :url
  end


end
