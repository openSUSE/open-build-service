class AddAttributeIndex < ActiveRecord::Migration
  def self.up
        add_index :attrib_types, :name
        add_index :attrib_types, :db_project_id
        add_index :attrib_namespaces, :name
  end

  def self.down
        remove_index :attrib_types, :column => ['name']
	remove_index :attrib_types, :column => ['db_project_id']
	remove_index :attrib_namespaces, :column => ['name']
  end
end
