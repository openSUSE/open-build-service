class AddAttribConfig < ActiveRecord::Migration
  def self.up
    create_table "attrib_types" do |t|
      t.integer :db_project_id
      t.integer :db_namespace_id
      t.string :name, :null => :false
      t.string :description
      t.string :type, :null => :false
    end

    create_table "attrib_allowed_values" do |t|
      t.integer :attrib_type_id, :null => :false
      t.text :value, :null => :false
    end

    create_table "attrib_default_values" do |t|
      t.integer :attrib_type_id, :null => :false
      t.text :value, :null => false
      t.integer :position, :null => :false
    end

    create_table "attrib_namespaces" do |t|
      t.string :name, :null => :false
    end
  end

  def self.down
    drop_table :attrib_types
    drop_table :attrib_allowed_values
    drop_table :attrib_default_values
    drop_table :attrib_namespaces
  end
end
