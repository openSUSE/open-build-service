class AddAttributeIndex2 < ActiveRecord::Migration
  def self.up
        add_index :attrib_values, :attrib_id
  end

  def self.down
        remove_index :attrib_values, :column => ['attrib_id']
  end
end
