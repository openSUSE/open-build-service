class AddMetaCache < ActiveRecord::Migration
  def self.up
    create_table "db_projects" do |t|
      t.column "name", :string, :null => false
      t.column "title", :string
      t.column "description", :text
    end

    add_index "db_projects", ["name"], :name => "projects_name_index"

    create_table "db_packages" do |t|
      t.column "db_project_id", :integer, :null => false
      t.column "name", :string, :null => false
      t.column "title", :string
      t.column "description", :text
    end

    add_index "db_packages", ["db_project_id", "name"], :name => "packages_all_index"

    create_table "project_user_role_relationships" do |t|
      t.column "db_project_id", :integer, :null => false
      t.column "bs_user_id", :integer, :null => false
      t.column "bs_role_id", :integer, :null => false
    end

    add_index "project_user_role_relationships", ["db_project_id", "bs_user_id", "bs_role_id"], :name => "project_user_role_all_index", :unique => true

    create_table "package_user_role_relationships" do |t|
      t.column "db_package_id", :integer, :null => false
      t.column "bs_user_id", :integer, :null => false
      t.column "bs_role_id", :integer, :null => false
    end

    add_index "package_user_role_relationships", ["db_package_id", "bs_user_id", "bs_role_id"], :name => "package_user_role_all_index", :unique => true

    create_table "tags" do |t|
      t.column "name", :string, :null => false
    end

    add_index "tags", ["name"], :name => "tags_name_unique_index", :unique => true

    create_table "db_projects_tags", :id => false do |t|
      t.column "db_project_id", :integer, :null => false
      t.column "tag_id", :integer, :null => false
    end

    add_index "db_projects_tags", ["db_project_id", "tag_id"], :name => "projects_tags_all_index", :unique => true

  end

  def self.down
    drop_table "db_projects"
    drop_table "db_packages"
    drop_table "project_user_role_relationships"
    drop_table "package_user_role_relationships"
    drop_table "tags"
    drop_table "db_projects_tags"
  end
end
