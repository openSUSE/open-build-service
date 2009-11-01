class AttribNamespaceDependend < ActiveRecord::Migration
  def self.up
    add_column :attrib_types, :attrib_namespace_id, :integer
    remove_column :attrib_types, :attrib_namespace
  end

  def self.down
    remove_column :attrib_types, :attrib_namespace_id
    add_column :attrib_types, :attrib_namespace, :string
  end
end
