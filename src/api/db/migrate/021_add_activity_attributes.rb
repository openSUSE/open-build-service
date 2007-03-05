class AddActivityAttributes < ActiveRecord::Migration


  def self.up
    add_column :db_packages, :update_counter, :integer, :default => 0
    add_column :db_packages, :activity_index, :float, :default => 100
  end


  def self.down
    remove_column :db_packages, :update_counter
    remove_column :db_packages, :activity_index
  end


end
