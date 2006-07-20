class AddMetaCache < ActiveRecord::Migration
  def self.up
    create_table "projects" do |t|
      t.column "name", :string, :null => false
      t.column "title", :string
      t.column "description", :text
    end

    add_index "projects", ["name"], :name => "projects_name_index", :unique => true

    create_table "packages" do |t|
      t.column "project_id", :integer, :null => false
      t.column "name", :string, :null => false
      t.column "title", :string
      t.column "description", :text
    end

    add_index "packages", ["project_id", "name"], :name => "packages_all_index", :unique => true

    create_table "projects_users_roles" do |t|
      t.column "project_id", :integer, :null => false
      t.column "bs_user_id", :integer, :null => false
      t.column "role_id", :integer, :null => false
    end

    add_index "projects_users_roles", ["project_id", "bs_user_id", "role_id"], :name => "project_user_role_all_index", :unique => true

    create_table "packages_users_roles" do |t|
      t.column "package_id", :integer, :null => false
      t.column "bs_user_id", :integer, :null => false
      t.column "role_id", :integer, :null => false
    end

    add_index "packages_users_roles", ["package_id", "bs_user_id", "role_id"], :name => "package_user_role_all_index", :unique => true

    create_table "tags" do |t|
      t.column "name", :string, :null => false
    end

    create_table "projects_tags" do |t|
      t.column "project_id", :integer, :null => false
      t.column "tag_id", :integer, :null => false
    end

    add_index "projects_tags", ["project_id", "tag_id"], :name => "projects_tags_all_index", :unique => true

    create_table "repositories" do |t|
      t.column "project_id", :integer
      t.column "name", :string
    end
  end

  def self.down
    drop_table "projects"
    drop_table "packages"
    drop_table "projects_users_roles"
    drop_table "packages_users_roles"
    drop_table "tags"
    drop_table "projects_tags"
  end
end
