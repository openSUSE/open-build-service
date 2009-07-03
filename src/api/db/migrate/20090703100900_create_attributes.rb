class CreateAttributes < ActiveRecord::Migration
  def self.up
    create_table :attributes do |t|
      t.integer :attrib_type_id, :null => false
      t.integer :db_package_id, :null => false
    end

    create_table :attrib_values do |t|
      t.integer :attribute_id, :null => false
      t.text :value, :null => false
      t.integer :position, :null => false
    end
  end

  def self.down
    drop_table :attributes
    drop_table :attrib_values
  end
end
