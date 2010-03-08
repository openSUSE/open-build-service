class AddGroupTables < ActiveRecord::Migration
  def self.up
    create_table "project_group_role_relationships" do |t|
      t.column "db_project_id", :integer, :null => false
      t.column "bs_group_id", :integer, :null => false
      t.column "role_id", :integer, :null => false
    end
    add_index "project_group_role_relationships", ["db_project_id", "bs_group_id", "role_id"], :name => "project_group_role_all_index", :unique => true

    create_table "package_group_role_relationships" do |t|
      t.column "db_package_id", :integer, :null => false
      t.column "bs_group_id", :integer, :null => false
      t.column "role_id", :integer, :null => false
    end
    add_index "package_group_role_relationships", ["db_package_id", "bs_group_id", "role_id"], :name => "package_group_role_all_index", :unique => true

  end

  def self.down
    drop_table "project_group_role_relationships"
    drop_table "package_group_role_relationships"
  end
end
