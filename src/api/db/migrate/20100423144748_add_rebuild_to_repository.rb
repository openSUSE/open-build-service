class AddRebuildToRepository < ActiveRecord::Migration
  def self.up
    add_column :repositories, :rebuild, "ENUM('transitive', 'direct', 'local')", :null => true
  end

  def self.down
    remove_column :repositories, :rebuild
  end
end
