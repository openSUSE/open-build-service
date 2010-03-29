class SetPositionNull < ActiveRecord::Migration
  def self.up
    change_column :flags, :position, :integer, :null => false
    change_column :path_elements, :position, :integer, :null => false
  end

  def self.down
    change_column :flags, :position, :integer, :null => true
    change_column :path_elements, :position, :integer, :null => true
  end
end
