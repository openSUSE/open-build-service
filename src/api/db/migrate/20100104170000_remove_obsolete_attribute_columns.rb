class RemoveObsoleteAttributeColumns < ActiveRecord::Migration
  def self.up
    # attribute definitions do not depend on projects anymore, but are global
    remove_column :attrib_namespace_modifiable_bies, :bs_role_id
    remove_column :attrib_namespaces, :db_project_id
    remove_column :attrib_types, :db_project_id
  end

  def self.down
    add_column :attrib_namespace_modifiable_bies, :bs_role_id, :integer
    add_column :attrib_namespaces, :db_project_id, :integer
    add_column :attrib_types, :db_project_id, :integer
  end
end
