class AddIndexForAttributes < ActiveRecord::Migration
  def self.up
    # attrib type definitions
    add_index :attrib_types, [:attrib_namespace_id, :name], :unique => true
    # attrib data
    add_index :attrib_values, [:attrib_id, :position], :unique => true
    add_index :attribs, [:attrib_type_id, :db_project_id, :db_package_id, :binary], :unique => true, :name => "attribs_on_proj_and_pack"
  end

  def self.down
    # attrib type definitions
    remove_index :attrib_types, [:attrib_namespace_id, :name]
    # attrib data
    remove_index :attrib_values, [:attrib_id, :position]
    remove_index :attribs, [:attrib_type_id, :db_project_id, :db_package_id, :binary], :name => "attribs_on_proj_and_pack"
  end
end
