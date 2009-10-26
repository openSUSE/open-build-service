class AttribTypesValues < ActiveRecord::Migration
  def self.up
    add_column :attrib_types, :value_count, :integer
  end

  def self.down
    remove_column :attrib_types, :value_count
  end
end
