class AddArchOrder < ActiveRecord::Migration
  def self.up
    add_column :architectures_repositories, :position, :integer, :null => false, :default => 0
  end

  def self.down
    remove_column :architectures_repositories, :position
  end
end
