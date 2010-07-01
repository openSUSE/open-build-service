# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20100702082339) do

  create_table "architectures", :force => true do |t|
    t.string  "name",                          :null => false
    t.boolean "selectable", :default => false
  end

  add_index "architectures", ["name"], :name => "arch_name_index", :unique => true

  create_table "architectures_repositories", :id => false, :force => true do |t|
    t.integer "repository_id",                  :null => false
    t.integer "architecture_id",                :null => false
    t.integer "position",        :default => 0, :null => false
  end

  add_index "architectures_repositories", ["repository_id", "architecture_id"], :name => "arch_repo_index", :unique => true

  create_table "attrib_allowed_values", :force => true do |t|
    t.integer "attrib_type_id", :null => false
    t.text    "value"
  end

  create_table "attrib_default_values", :force => true do |t|
    t.integer "attrib_type_id", :null => false
    t.text    "value",          :null => false
    t.integer "position",       :null => false
  end

  create_table "attrib_namespace_modifiable_bies", :force => true do |t|
    t.integer "attrib_namespace_id", :null => false
    t.integer "bs_user_id"
    t.integer "bs_group_id"
  end

  add_index "attrib_namespace_modifiable_bies", ["attrib_namespace_id", "bs_user_id", "bs_group_id"], :name => "attrib_namespace_user_role_all_index", :unique => true

  create_table "attrib_namespaces", :force => true do |t|
    t.string "name"
  end

  add_index "attrib_namespaces", ["name"], :name => "index_attrib_namespaces_on_name"

  create_table "attrib_type_modifiable_bies", :force => true do |t|
    t.integer "attrib_type_id", :null => false
    t.integer "bs_user_id"
    t.integer "bs_group_id"
    t.integer "bs_role_id"
  end

  add_index "attrib_type_modifiable_bies", ["attrib_type_id", "bs_user_id", "bs_group_id", "bs_role_id"], :name => "attrib_type_user_role_all_index", :unique => true

  create_table "attrib_types", :force => true do |t|
    t.string  "name",                :null => false
    t.string  "description"
    t.string  "type"
    t.integer "value_count"
    t.integer "attrib_namespace_id", :null => false
  end

  add_index "attrib_types", ["name"], :name => "index_attrib_types_on_name"

  create_table "attrib_values", :force => true do |t|
    t.integer "attrib_id", :null => false
    t.text    "value",     :null => false
    t.integer "position",  :null => false
  end

  add_index "attrib_values", ["attrib_id"], :name => "index_attrib_values_on_attrib_id"

  create_table "attribs", :force => true do |t|
    t.integer "attrib_type_id", :null => false
    t.integer "db_package_id"
    t.string  "binary"
    t.integer "db_project_id"
  end

  add_index "attribs", ["attrib_type_id", "db_package_id", "db_project_id", "binary"], :name => "attribs_index", :unique => true

  create_table "blacklist_tags", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
  end

  create_table "db_packages", :force => true do |t|
    t.integer  "db_project_id",                                     :null => false
    t.binary   "name",            :limit => 255,                    :null => false
    t.string   "title"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "url"
    t.integer  "update_counter",                 :default => 0
    t.float    "activity_index",                 :default => 100.0
    t.integer  "develproject_id"
    t.string   "bcntsynctag"
    t.integer  "develpackage_id"
  end

  execute "CREATE UNIQUE INDEX packages_all_index ON db_packages (db_project_id,name(255));"
  add_index "db_packages", ["db_project_id"], :name => "index_db_packages_on_db_project_id"
  add_index "db_packages", ["develpackage_id"], :name => "devel_package_id_index"
  add_index "db_packages", ["develproject_id"], :name => "devel_project_id_index"

  create_table "db_projects", :force => true do |t|
    t.binary   "name",          :limit => 255, :null => false
    t.string   "title"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "remoteurl"
    t.string   "remoteproject"
  end

  execute "CREATE UNIQUE INDEX projects_name_index ON db_projects (name(255));"

  create_table "db_projects_tags", :id => false, :force => true do |t|
    t.integer "db_project_id", :null => false
    t.integer "tag_id",        :null => false
  end

  add_index "db_projects_tags", ["db_project_id", "tag_id"], :name => "projects_tags_all_index", :unique => true

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "download_stats", :force => true do |t|
    t.integer  "db_project_id"
    t.integer  "db_package_id"
    t.integer  "repository_id"
    t.integer  "architecture_id"
    t.string   "filename"
    t.string   "filetype",        :limit => 10
    t.string   "version"
    t.string   "release"
    t.datetime "created_at"
    t.datetime "counted_at"
    t.integer  "count"
  end

  add_index "download_stats", ["architecture_id"], :name => "arch"
  add_index "download_stats", ["db_package_id"], :name => "package"
  add_index "download_stats", ["db_project_id"], :name => "project"
  add_index "download_stats", ["repository_id"], :name => "repository"

  create_table "downloads", :force => true do |t|
    t.string  "baseurl"
    t.string  "metafile"
    t.string  "mtype"
    t.integer "architecture_id"
    t.integer "db_project_id"
  end

  create_table "flags", :force => true do |t|
    t.string  "status"
    t.string  "repo"
    t.integer "db_project_id"
    t.integer "db_package_id"
    t.integer "architecture_id"
    t.integer "position",                     :null => false
    t.string  "flag",                         :null => false
  end

  add_index "flags", ["db_package_id"], :name => "index_flags_on_db_package_id"
  add_index "flags", ["db_project_id"], :name => "index_flags_on_db_project_id"

  create_table "groups", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "title",      :limit => 200, :default => "", :null => false
    t.integer  "parent_id"
  end

  add_index "groups", ["parent_id"], :name => "groups_parent_id_index"

  create_table "groups_roles", :id => false, :force => true do |t|
    t.integer  "group_id",   :default => 0, :null => false
    t.integer  "role_id",    :default => 0, :null => false
    t.datetime "created_at"
  end

  add_index "groups_roles", ["group_id", "role_id"], :name => "groups_roles_all_index", :unique => true
  add_index "groups_roles", ["role_id"], :name => "role_id"

  create_table "groups_users", :id => false, :force => true do |t|
    t.integer  "group_id",   :default => 0, :null => false
    t.integer  "user_id",    :default => 0, :null => false
    t.datetime "created_at"
  end

  add_index "groups_users", ["group_id", "user_id"], :name => "groups_users_all_index", :unique => true
  add_index "groups_users", ["user_id"], :name => "user_id"

  create_table "linked_projects", :force => true do |t|
    t.integer "db_project_id",              :null => false
    t.integer "linked_db_project_id"
    t.integer "position"
    t.string  "linked_remote_project_name"
  end

  add_index "linked_projects", ["db_project_id", "linked_db_project_id"], :name => "linked_projects_index", :unique => true

  create_table "messages", :force => true do |t|
    t.integer  "object_id"
    t.string   "object_type"
    t.integer  "user_id"
    t.datetime "created_at"
    t.boolean  "send_mail"
    t.datetime "sent_at"
    t.boolean  "private"
    t.integer  "severity"
    t.text     "text"
  end

  add_index "messages", ["object_id"], :name => "object"
  add_index "messages", ["user_id"], :name => "user"

  create_table "package_group_role_relationships", :force => true do |t|
    t.integer "db_package_id", :null => false
    t.integer "bs_group_id",   :null => false
    t.integer "role_id",       :null => false
  end

  add_index "package_group_role_relationships", ["db_package_id", "bs_group_id", "role_id"], :name => "package_group_role_all_index", :unique => true

  create_table "package_user_role_relationships", :force => true do |t|
    t.integer "db_package_id", :null => false
    t.integer "bs_user_id",    :null => false
    t.integer "role_id",       :null => false
  end

  add_index "package_user_role_relationships", ["bs_user_id"], :name => "index_package_user_role_relationships_on_bs_user_id"
  add_index "package_user_role_relationships", ["db_package_id", "bs_user_id", "role_id"], :name => "package_user_role_all_index", :unique => true

  create_table "path_elements", :force => true do |t|
    t.integer "parent_id",     :null => false
    t.integer "repository_id", :null => false
    t.integer "position",      :null => false
  end

  add_index "path_elements", ["parent_id", "position"], :name => "parent_repo_pos_index", :unique => true
  add_index "path_elements", ["parent_id", "repository_id"], :name => "parent_repository_index", :unique => true

  create_table "project_group_role_relationships", :force => true do |t|
    t.integer "db_project_id", :null => false
    t.integer "bs_group_id",   :null => false
    t.integer "role_id",       :null => false
  end

  add_index "project_group_role_relationships", ["db_project_id", "bs_group_id", "role_id"], :name => "project_group_role_all_index", :unique => true

  create_table "project_user_role_relationships", :force => true do |t|
    t.integer "db_project_id", :null => false
    t.integer "bs_user_id",    :null => false
    t.integer "role_id",       :null => false
  end

  add_index "project_user_role_relationships", ["db_project_id", "bs_user_id", "role_id"], :name => "project_user_role_all_index", :unique => true

  create_table "ratings", :force => true do |t|
    t.integer  "score"
    t.integer  "object_id"
    t.string   "object_type"
    t.datetime "created_at"
    t.integer  "user_id"
  end

  add_index "ratings", ["object_id"], :name => "object"
  add_index "ratings", ["user_id"], :name => "user"

  create_table "repositories", :force => true do |t|
    t.integer "db_project_id",                    :null => false
    t.string  "name"
    t.string  "remote_project_name"
    t.string  "rebuild",             :limit => 0
    t.string  "block",               :limit => 0
    t.string  "linkedbuild",         :limit => 0
  end

  add_index "repositories", ["db_project_id", "name", "remote_project_name"], :name => "projects_name_index", :unique => true
  add_index "repositories", ["remote_project_name"], :name => "remote_project_name_index"

  create_table "roles", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "title",      :limit => 100, :default => "",    :null => false
    t.integer  "parent_id"
    t.boolean  "global",                    :default => false
  end

  add_index "roles", ["parent_id"], :name => "roles_parent_id_index"

  create_table "roles_static_permissions", :id => false, :force => true do |t|
    t.integer  "role_id",              :default => 0, :null => false
    t.integer  "static_permission_id", :default => 0, :null => false
    t.datetime "created_at"
  end

  add_index "roles_static_permissions", ["role_id"], :name => "role_id"
  add_index "roles_static_permissions", ["static_permission_id", "role_id"], :name => "roles_static_permissions_all_index", :unique => true

  create_table "roles_users", :id => false, :force => true do |t|
    t.integer  "user_id",    :default => 0, :null => false
    t.integer  "role_id",    :default => 0, :null => false
    t.datetime "created_at"
  end

  add_index "roles_users", ["role_id"], :name => "role_id"
  add_index "roles_users", ["user_id", "role_id"], :name => "roles_users_all_index", :unique => true

  create_table "static_permissions", :force => true do |t|
    t.string   "title",      :limit => 200, :default => "", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "static_permissions", ["title"], :name => "static_permissions_title_index", :unique => true

  create_table "status_histories", :force => true do |t|
    t.integer "time"
    t.string  "key"
    t.integer "value"
  end

  add_index "status_histories", ["time", "key"], :name => "index_status_histories_on_time_and_key"

  create_table "status_messages", :force => true do |t|
    t.datetime "created_at"
    t.datetime "deleted_at"
    t.text     "message"
    t.integer  "user_id"
    t.integer  "severity"
  end

  add_index "status_messages", ["user_id"], :name => "user"

  create_table "taggings", :force => true do |t|
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.integer  "tag_id"
    t.integer  "user_id"
    t.datetime "created_at"
  end

  add_index "taggings", ["taggable_id", "taggable_type", "tag_id", "user_id"], :name => "taggings_taggable_id_index", :unique => true
  add_index "taggings", ["taggable_type"], :name => "index_taggings_on_taggable_type"

  create_table "tags", :force => true do |t|
    t.string   "name",       :null => false
    t.datetime "created_at"
  end

  add_index "tags", ["name"], :name => "tags_name_unique_index", :unique => true

  create_table "user_registrations", :force => true do |t|
    t.integer  "user_id",    :default => 0, :null => false
    t.text     "token",                     :null => false
    t.datetime "created_at"
    t.datetime "expires_at"
  end

  add_index "user_registrations", ["expires_at"], :name => "user_registrations_expires_at_index"
  add_index "user_registrations", ["user_id"], :name => "user_registrations_user_id_index", :unique => true

  create_table "users", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "last_logged_in_at"
    t.integer  "login_failure_count",                :default => 0,            :null => false
    t.binary   "login",               :limit => 255,                           :null => false
    t.string   "email",               :limit => 200, :default => "",           :null => false
    t.string   "realname",            :limit => 200, :default => "",           :null => false
    t.string   "password",            :limit => 100, :default => "",           :null => false
    t.string   "password_hash_type",  :limit => 20,  :default => "",           :null => false
    t.string   "password_salt",       :limit => 10,  :default => "1234512345", :null => false
    t.string   "password_crypted",    :limit => 64
    t.integer  "state",                              :default => 1,            :null => false
    t.text     "adminnote"
  end

  execute "CREATE UNIQUE INDEX users_login_index ON users (login(255));"
  add_index "users", ["password"], :name => "users_password_index"

  create_table "watched_projects", :force => true do |t|
    t.integer "bs_user_id",                :default => 0,  :null => false
    t.string  "name",       :limit => 100, :default => "", :null => false
  end

  add_index "watched_projects", ["bs_user_id"], :name => "watched_projects_users_fk_1"

end
