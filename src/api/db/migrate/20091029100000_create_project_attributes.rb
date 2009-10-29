class CreateProjectAttributes < ActiveRecord::Migration
  def self.up
    add_column :attribs, :db_project_id, :integer
    add_index :attribs, ["attrib_type_id", "db_package_id", "db_project_id", "subpackage"], :name => "attribs_index", :unique => true
    change_column :attribs, :db_package_id, :integer, :null => true
  end

  def self.down
    remove_column :attribs, :db_project_id
    remove_index :attribs, :name => "attribs_index"
    change_column :attribs, :db_package_id, :integer, :null => false
  end
end
