class AddPackageColumnToFlagsTable < ActiveRecord::Migration
  def self.up
    add_column :flags, :package, :binary, :limit => 256, :null => true
  end

  def self.down
    remove_column :flags, :package
  end
end
