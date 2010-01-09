class SetSomeNotNull < ActiveRecord::Migration
  def self.up
    change_column :architectures_repositories, :architecture_id, :integer, :null => false
    change_column :architectures_repositories, :repository_id, :integer, :null => false
    change_column :architectures, :name, :string, :null => false
    change_column :path_elements, :parent_id, :integer, :null => false
    change_column :path_elements, :repository_id, :integer, :null => false
    change_column :repositories, :db_project_id, :integer, :null => false
    change_column :attrib_allowed_values, :attrib_type_id, :integer, :null => false
    change_column :attrib_default_values, :attrib_type_id, :integer, :null => false
    change_column :attrib_default_values, :position, :integer, :null => false
    change_column :attrib_types, :name, :string, :null => false
    change_column :attrib_types, :attrib_namespace_id, :integer, :null => false
  end

  def self.down
    change_column :architectures_repositories, :architecture_id, :integer
    change_column :architectures_repositories, :repository_id, :integer
    change_column :architectures, :name, :string
    change_column :path_elements, :parent_id, :integer
    change_column :path_elements, :repository_id, :integer
    change_column :repositories, :db_project_id, :integer
    change_column :attrib_allowed_values, :attrib_type_id, :integer
    change_column :attrib_allowed_values, :attrib_type_id, :integer
    change_column :attrib_allowed_values, :position, :integer
    change_column :attrib_types, :name, :string
    change_column :attrib_types, :attrib_namespace_id, :integer
  end
end
