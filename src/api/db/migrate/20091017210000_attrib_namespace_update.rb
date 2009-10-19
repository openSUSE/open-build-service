class AttribNamespaceUpdate < ActiveRecord::Migration
  def self.up
    add_column :attrib_namespaces, :db_project_id, :integer
    add_column :attrib_types, :attrib_namespace, :string
  end

  def self.down
    remove_column :attrib_namespaces, :db_project_id
    remove_column :attrib_types, :attrib_namespace
  end
end
