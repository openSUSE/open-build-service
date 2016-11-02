class RemoveUniqueIndexFromAttribValues < ActiveRecord::Migration
  def self.up
    remove_index :attrib_values, [:attrib_id, :position]
  end

  def self.down
    add_index :attrib_values, [:attrib_id, :position], unique: true
  end
end
