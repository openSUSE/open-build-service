class InitialDatabase < ActiveRecord::Migration
  def self.up

    puts "Please don't use db:migrate to create an initial database."
    puts "Please use \"rake db:setup\" instead!"
    puts "Aborting..."
    return 1

    # === groups table ===
    
    create_table "groups", :force => true do |t|
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
      t.column "title", :string, :limit => 200, :default => "", :null => false
      t.column "parent_id", :integer, :limit => 10
    end

    add_index "groups", ["parent_id"], :name => "groups_parent_id_index"

    # === groups_roles table ===
    
    create_table "groups_roles", :id => false, :force => true do |t|
      t.column "group_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "role_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "created_at", :timestamp
    end

    add_index "groups_roles", ["group_id", "role_id"], :name => "groups_roles_all_index", :unique => true
    add_index "groups_roles", ["role_id"], :name => "role_id"

    # === groups_users table ===
    
    create_table "groups_users", :id => false, :force => true do |t|
      t.column "group_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "user_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "created_at", :timestamp
    end

    add_index "groups_users", ["group_id", "user_id"], :name => "groups_users_all_index", :unique => true
    add_index "groups_users", ["user_id"], :name => "user_id"

    # === roles table ===
    
    create_table "roles", :force => true do |t|
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
      t.column "title", :string, :limit => 100, :default => "", :null => false
      t.column "parent_id", :integer, :limit => 10
    end

    add_index "roles", ["parent_id"], :name => "roles_parent_id_index"

    Role.create :title => "Admin"
    Role.create :title => "User"

    # === roles_static_permissions table ===
    
    create_table "roles_static_permissions", :id => false, :force => true do |t|
      t.column "role_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "static_permission_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "created_at", :timestamp
    end

    add_index "roles_static_permissions", ["static_permission_id", "role_id"], :name => "roles_static_permissions_all_index", :unique => true
    add_index "roles_static_permissions", ["role_id"], :name => "role_id"

    execute "INSERT INTO `roles_static_permissions` VALUES (1,1,NOW()),(1,2,NOW()),(1,3,NOW()),(1,4,NOW()), (2,2,NOW())"

    # === roles_users table ===
    
    create_table "roles_users", :id => false, :force => true do |t|
      t.column "user_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "role_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "created_at", :timestamp
    end

    add_index "roles_users", ["user_id", "role_id"], :name => "roles_users_all_index", :unique => true
    add_index "roles_users", ["role_id"], :name => "role_id"

    execute "INSERT INTO `roles_users` VALUES (1,1,NOW())"

    # === static_permissions table ===
    
    create_table "static_permissions", :force => true do |t|
      t.column "title", :string, :limit => 200, :default => "", :null => false
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
    end

    add_index "static_permissions", ["title"], :name => "static_permissions_title_index", :unique => true

    # !!! don't change the order of the create statements or the ids will be wrong
    StaticPermission.create :title => "global_project_change"
    StaticPermission.create :title => "global_project_create"
    StaticPermission.create :title => "global_package_change"
    StaticPermission.create :title => "global_package_create"

    # === user_registrations table ===
    
    create_table "user_registrations", :force => true do |t|
      t.column "user_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "token", :text, :default => "", :null => false
      t.column "created_at", :timestamp
      t.column "expires_at", :timestamp
    end

    add_index "user_registrations", ["user_id"], :name => "user_registrations_user_id_index", :unique => true
    add_index "user_registrations", ["expires_at"], :name => "user_registrations_expires_at_index"

    # === users table ===
    
    create_table "users", :force => true do |t|
      t.column "created_at", :timestamp
      t.column "updated_at", :timestamp
      t.column "last_logged_in_at", :timestamp
      t.column "login_failure_count", :integer, :limit => 10, :default => 0, :null => false
      t.column "login", :string, :limit => 100, :default => "", :null => false
      t.column "email", :string, :limit => 200, :default => "", :null => false
      t.column "realname", :string, :limit => 200, :default => "", :null => false
      t.column "password", :string, :limit => 100, :default => "", :null => false
      t.column "password_hash_type", :string, :limit => 20, :default => "", :null => false
      t.column "password_salt", :string, :limit => 10, :default => "1234512345", :null => false
      t.column "password_crypted", :string, :limit => 64
      t.column "state", :integer, :limit => 10, :default => 1, :null => false
      t.column "source_host", :string, :limit => 40
      t.column "source_port", :integer
      t.column "rpm_host", :string, :limit => 40
      t.column "rpm_port", :integer
    end

    add_index "users", ["login"], :name => "users_login_index", :unique => true
    add_index "users", ["password"], :name => "users_password_index"

    User.create :login => "Admin", :email => "root@localhost", :state => "2", :password => "opensuse", :password_confirmation => "opensuse"

    # === watched_projects table ===

    create_table "watched_projects", :force => true do |t|
      t.column "bs_user_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "name", :string, :limit => 100, :default => "", :null => false
    end

    add_index "watched_projects", ["bs_user_id"], :name => "watched_projects_users_fk_1"
  end

  def self.down
    drop_table "groups"
    drop_table "groups_roles"
    drop_table "groups_users"
    drop_table "roles"
    drop_table "roles_static_permissions"
    drop_table "roles_users"
    drop_table "static_permissions"
    drop_table "user_registrations"
    drop_table "users"
    drop_table "watched_projects"
  end
end
