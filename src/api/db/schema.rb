# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2022_01_26_155601) do

  create_table "architectures", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false, collation: "utf8_general_ci"
    t.boolean "available", default: false
    t.index ["name"], name: "arch_name_index", unique: true
  end

  create_table "architectures_distributions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "distribution_id"
    t.integer "architecture_id"
  end

  create_table "attrib_allowed_values", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "attrib_type_id", null: false
    t.text "value"
    t.index ["attrib_type_id"], name: "attrib_type_id"
  end

  create_table "attrib_default_values", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "attrib_type_id", null: false
    t.text "value", null: false
    t.integer "position", null: false
    t.index ["attrib_type_id"], name: "attrib_type_id"
  end

  create_table "attrib_issues", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "attrib_id", null: false
    t.integer "issue_id", null: false
    t.index ["attrib_id", "issue_id"], name: "index_attrib_issues_on_attrib_id_and_issue_id", unique: true
    t.index ["issue_id"], name: "issue_id"
  end

  create_table "attrib_namespace_modifiable_bies", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "attrib_namespace_id", null: false
    t.integer "user_id"
    t.integer "group_id"
    t.index ["attrib_namespace_id", "user_id", "group_id"], name: "attrib_namespace_user_role_all_index", unique: true
    t.index ["group_id"], name: "bs_group_id"
    t.index ["user_id"], name: "bs_user_id"
  end

  create_table "attrib_namespaces", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", collation: "utf8_general_ci"
    t.index ["name"], name: "index_attrib_namespaces_on_name"
  end

  create_table "attrib_type_modifiable_bies", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "attrib_type_id", null: false
    t.integer "user_id"
    t.integer "group_id"
    t.integer "role_id"
    t.index ["attrib_type_id", "user_id", "group_id", "role_id"], name: "attrib_type_user_role_all_index", unique: true
    t.index ["group_id"], name: "group_id"
    t.index ["role_id"], name: "role_id"
    t.index ["user_id"], name: "user_id"
  end

  create_table "attrib_types", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false, collation: "utf8_general_ci"
    t.string "description", collation: "utf8_general_ci"
    t.string "type", collation: "utf8_general_ci"
    t.integer "value_count"
    t.integer "attrib_namespace_id", null: false
    t.boolean "issue_list", default: false
    t.index ["attrib_namespace_id", "name"], name: "index_attrib_types_on_attrib_namespace_id_and_name", unique: true
    t.index ["name"], name: "index_attrib_types_on_name"
  end

  create_table "attrib_values", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "attrib_id", null: false
    t.text "value", null: false
    t.integer "position", null: false
    t.index ["attrib_id"], name: "index_attrib_values_on_attrib_id"
  end

  create_table "attribs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "attrib_type_id", null: false
    t.integer "package_id"
    t.string "binary", collation: "utf8_general_ci"
    t.integer "project_id"
    t.index ["attrib_type_id", "package_id", "project_id", "binary"], name: "attribs_index", unique: true
    t.index ["attrib_type_id", "project_id", "package_id", "binary"], name: "attribs_on_proj_and_pack", unique: true
    t.index ["package_id"], name: "index_attribs_on_package_id"
    t.index ["project_id"], name: "index_attribs_on_project_id"
  end

  create_table "backend_infos", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "key", null: false, collation: "utf8_unicode_ci"
    t.string "value", null: false, collation: "utf8_unicode_ci"
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
  end

  create_table "backend_packages", primary_key: "package_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "links_to_id"
    t.datetime "updated_at", precision: 6
    t.string "srcmd5", collation: "utf8_unicode_ci"
    t.string "changesmd5", collation: "utf8_unicode_ci"
    t.string "verifymd5", collation: "utf8_unicode_ci"
    t.string "expandedmd5", collation: "utf8_unicode_ci"
    t.text "error"
    t.datetime "maxmtime"
    t.index ["links_to_id"], name: "index_backend_packages_on_links_to_id"
  end

  create_table "binary_releases", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.column "operation", "enum('added','removed','modified')", default: "added", collation: "utf8_general_ci"
    t.datetime "obsolete_time"
    t.integer "release_package_id"
    t.string "binary_name", null: false, collation: "utf8_general_ci"
    t.string "binary_epoch", limit: 64, collation: "utf8_general_ci"
    t.string "binary_version", limit: 64, null: false, collation: "utf8_general_ci"
    t.string "binary_release", limit: 64, null: false, collation: "utf8_general_ci"
    t.string "binary_arch", limit: 64, null: false, collation: "utf8_general_ci"
    t.string "binary_disturl", collation: "utf8_general_ci"
    t.datetime "binary_buildtime"
    t.datetime "binary_releasetime", null: false
    t.string "binary_supportstatus", collation: "utf8_general_ci"
    t.string "binary_maintainer", collation: "utf8_general_ci"
    t.string "medium", collation: "utf8_general_ci"
    t.string "binary_updateinfo", collation: "utf8_general_ci"
    t.string "binary_updateinfo_version", collation: "utf8_general_ci"
    t.datetime "modify_time"
    t.integer "on_medium_id"
    t.string "binary_id", collation: "utf8_general_ci"
    t.string "flavor", collation: "utf8_general_ci"
    t.string "binary_cpeid", collation: "utf8_general_ci"
    t.index ["binary_id"], name: "index_binary_releases_on_binary_id"
    t.index ["binary_name", "binary_arch"], name: "index_binary_releases_on_binary_name_and_binary_arch"
    t.index ["binary_name", "binary_epoch", "binary_version", "binary_release", "binary_arch"], name: "exact_search_index"
    t.index ["binary_updateinfo"], name: "index_binary_releases_on_binary_updateinfo"
    t.index ["medium"], name: "index_binary_releases_on_medium"
    t.index ["release_package_id"], name: "release_package_id"
    t.index ["repository_id", "binary_name"], name: "ra_name_index"
  end

  create_table "bs_request_action_accept_infos", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "bs_request_action_id"
    t.string "rev", collation: "utf8_unicode_ci"
    t.string "srcmd5", collation: "utf8_unicode_ci"
    t.string "xsrcmd5", collation: "utf8_unicode_ci"
    t.string "osrcmd5", collation: "utf8_unicode_ci"
    t.string "oxsrcmd5", collation: "utf8_unicode_ci"
    t.datetime "created_at"
    t.string "oproject", collation: "utf8_unicode_ci"
    t.string "opackage", collation: "utf8_unicode_ci"
    t.index ["bs_request_action_id"], name: "bs_request_action_id"
  end

  create_table "bs_request_actions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "bs_request_id"
    t.string "type", collation: "utf8_bin"
    t.string "target_project", collation: "utf8_unicode_ci"
    t.string "target_package", collation: "utf8_unicode_ci"
    t.string "target_releaseproject", collation: "utf8_unicode_ci"
    t.string "source_project", collation: "utf8_unicode_ci"
    t.string "source_package", collation: "utf8_unicode_ci"
    t.string "source_rev", collation: "utf8_unicode_ci"
    t.string "sourceupdate", collation: "utf8_unicode_ci"
    t.boolean "updatelink", default: false
    t.string "person_name", collation: "utf8_unicode_ci"
    t.string "group_name", collation: "utf8_unicode_ci"
    t.string "role", collation: "utf8_unicode_ci"
    t.datetime "created_at"
    t.string "target_repository", collation: "utf8_bin"
    t.boolean "makeoriginolder", default: false
    t.integer "target_package_id"
    t.integer "target_project_id"
    t.index ["bs_request_id", "target_package_id"], name: "index_bs_request_actions_on_bs_request_id_and_target_package_id"
    t.index ["bs_request_id", "target_project_id"], name: "index_bs_request_actions_on_bs_request_id_and_target_project_id"
    t.index ["bs_request_id"], name: "bs_request_id"
    t.index ["source_package"], name: "index_bs_request_actions_on_source_package"
    t.index ["source_project"], name: "index_bs_request_actions_on_source_project"
    t.index ["target_package"], name: "index_bs_request_actions_on_target_package"
    t.index ["target_package_id"], name: "index_bs_request_actions_on_target_package_id"
    t.index ["target_project"], name: "index_bs_request_actions_on_target_project"
    t.index ["target_project_id"], name: "index_bs_request_actions_on_target_project_id"
  end

  create_table "bs_request_counter", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "counter", default: 1
  end

  create_table "bs_requests", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.text "description"
    t.string "creator", collation: "utf8_unicode_ci"
    t.string "state", collation: "utf8_unicode_ci"
    t.text "comment"
    t.string "commenter", collation: "utf8_unicode_ci"
    t.integer "superseded_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "accept_at"
    t.column "priority", "enum('critical','important','moderate','low')", default: "moderate", collation: "utf8_bin"
    t.integer "number"
    t.datetime "updated_when"
    t.string "approver"
    t.integer "staging_project_id"
    t.index ["creator"], name: "index_bs_requests_on_creator"
    t.index ["number"], name: "index_bs_requests_on_number", unique: true
    t.index ["staging_project_id"], name: "index_bs_requests_on_staging_project_id"
    t.index ["state"], name: "index_bs_requests_on_state"
    t.index ["superseded_by"], name: "index_bs_requests_on_superseded_by"
  end

  create_table "channel_binaries", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false, collation: "utf8_unicode_ci"
    t.integer "channel_binary_list_id", null: false
    t.integer "project_id"
    t.integer "repository_id"
    t.integer "architecture_id"
    t.string "package", collation: "utf8_unicode_ci"
    t.string "binaryarch", collation: "utf8_unicode_ci"
    t.string "supportstatus", collation: "utf8_unicode_ci"
    t.index ["architecture_id"], name: "architecture_id"
    t.index ["channel_binary_list_id"], name: "channel_binary_list_id"
    t.index ["name", "channel_binary_list_id"], name: "index_channel_binaries_on_name_and_channel_binary_list_id"
    t.index ["project_id", "package"], name: "index_channel_binaries_on_project_id_and_package"
    t.index ["repository_id"], name: "repository_id"
  end

  create_table "channel_binary_lists", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.integer "project_id"
    t.integer "repository_id"
    t.integer "architecture_id"
    t.index ["architecture_id"], name: "architecture_id"
    t.index ["channel_id"], name: "channel_id"
    t.index ["project_id"], name: "project_id"
    t.index ["repository_id"], name: "repository_id"
  end

  create_table "channel_targets", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "channel_id", null: false
    t.integer "repository_id", null: false
    t.string "prefix", collation: "utf8_unicode_ci"
    t.string "id_template", collation: "utf8_unicode_ci"
    t.boolean "disabled", default: false
    t.boolean "requires_issue"
    t.index ["channel_id", "repository_id"], name: "index_channel_targets_on_channel_id_and_repository_id", unique: true
    t.index ["repository_id"], name: "repository_id"
  end

  create_table "channels", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "package_id", null: false
    t.boolean "disabled"
    t.index ["package_id"], name: "index_unique", unique: true
  end

  create_table "cloud_azure_configurations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "user_id"
    t.text "application_id", collation: "utf8_general_ci"
    t.text "application_key", collation: "utf8_general_ci"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_cloud_azure_configurations_on_user_id"
  end

  create_table "cloud_ec2_configurations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "user_id"
    t.string "external_id", collation: "utf8_general_ci"
    t.string "arn", collation: "utf8_general_ci"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id", "arn"], name: "index_cloud_ec2_configurations_on_external_id_and_arn", unique: true
    t.index ["user_id"], name: "index_cloud_ec2_configurations_on_user_id"
  end

  create_table "cloud_user_upload_jobs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "user_id"
    t.integer "job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_cloud_user_upload_jobs_on_job_id", unique: true
    t.index ["user_id"], name: "index_cloud_user_upload_jobs_on_user_id"
  end

  create_table "comments", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.text "body"
    t.integer "parent_id"
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.integer "user_id", null: false
    t.string "commentable_type", collation: "utf8_unicode_ci"
    t.integer "commentable_id"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["parent_id"], name: "parent_id"
    t.index ["user_id"], name: "user_id"
  end

  create_table "commit_activities", id: :integer, charset: "utf8", collation: "utf8_bin", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.date "date", null: false
    t.integer "user_id", null: false
    t.string "project", null: false
    t.string "package", null: false
    t.integer "count", default: 0, null: false
    t.index ["date", "user_id", "project", "package"], name: "unique_activity_day", unique: true
    t.index ["user_id", "date"], name: "index_commit_activities_on_user_id_and_date"
    t.index ["user_id"], name: "index_commit_activities_on_user_id"
  end

  create_table "configurations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "title", default: "", collation: "utf8_bin"
    t.text "description"
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.string "name", default: "", collation: "utf8_bin"
    t.column "registration", "enum('allow','confirmation','deny')", default: "allow", collation: "utf8_bin"
    t.boolean "anonymous", default: true
    t.boolean "default_access_disabled", default: false
    t.boolean "allow_user_to_create_home_project", default: true
    t.boolean "disallow_group_creation", default: false
    t.boolean "change_password", default: true
    t.boolean "hide_private_options", default: false
    t.boolean "gravatar", default: true
    t.boolean "enforce_project_keys", default: false
    t.boolean "download_on_demand", default: true
    t.string "download_url", collation: "utf8_bin"
    t.string "ymp_url", collation: "utf8_bin"
    t.string "bugzilla_url", collation: "utf8_bin"
    t.string "http_proxy", collation: "utf8_bin"
    t.string "no_proxy", collation: "utf8_bin"
    t.string "theme", collation: "utf8_bin"
    t.string "obs_url", default: "https://unconfigured.openbuildservice.org", collation: "utf8_bin"
    t.integer "cleanup_after_days"
    t.string "admin_email", default: "unconfigured@openbuildservice.org", collation: "utf8_bin"
    t.boolean "cleanup_empty_projects", default: true
    t.boolean "disable_publish_for_branches", default: true
    t.string "default_tracker", default: "bnc", collation: "utf8_bin"
    t.string "api_url", collation: "utf8_bin"
    t.string "unlisted_projects_filter", default: "^home:.+", collation: "utf8_bin"
    t.string "unlisted_projects_filter_description", default: "home projects", collation: "utf8_bin"
    t.string "tos_url"
  end

  create_table "data_migrations", primary_key: "version", id: :string, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
  end

  create_table "delayed_jobs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler", size: :medium, collation: "utf8_bin"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by", collation: "utf8_general_ci"
    t.string "queue", collation: "utf8_general_ci"
    t.index ["queue"], name: "index_delayed_jobs_on_queue"
  end

  create_table "distribution_icons", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "url", null: false, collation: "utf8_unicode_ci"
    t.integer "width"
    t.integer "height"
  end

  create_table "distribution_icons_distributions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "distribution_id"
    t.integer "distribution_icon_id"
  end

  create_table "distributions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "vendor", null: false, collation: "utf8_unicode_ci"
    t.string "version", null: false, collation: "utf8_unicode_ci"
    t.string "name", null: false, collation: "utf8_unicode_ci"
    t.string "project", null: false, collation: "utf8_unicode_ci"
    t.string "reponame", null: false, collation: "utf8_unicode_ci"
    t.string "repository", null: false, collation: "utf8_unicode_ci"
    t.string "link", collation: "utf8_unicode_ci"
    t.boolean "remote", default: false
  end

  create_table "download_repositories", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.string "arch", null: false, collation: "utf8_general_ci"
    t.string "url", null: false, collation: "utf8_general_ci"
    t.string "repotype", collation: "utf8_general_ci"
    t.string "archfilter", collation: "utf8_general_ci"
    t.string "masterurl", collation: "utf8_general_ci"
    t.string "mastersslfingerprint", collation: "utf8_general_ci"
    t.text "pubkey", collation: "utf8_general_ci"
    t.index ["repository_id"], name: "repository_id"
  end

  create_table "event_subscriptions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "eventtype", null: false, collation: "utf8_unicode_ci"
    t.string "receiver_role", null: false, collation: "utf8_unicode_ci"
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.integer "group_id"
    t.integer "channel", default: 0, null: false
    t.boolean "enabled", default: false
    t.integer "token_id"
    t.text "payload"
    t.integer "package_id"
    t.index ["group_id"], name: "index_event_subscriptions_on_group_id"
    t.index ["package_id"], name: "index_event_subscriptions_on_package_id"
    t.index ["token_id"], name: "index_event_subscriptions_on_token_id"
    t.index ["user_id"], name: "index_event_subscriptions_on_user_id"
  end

  create_table "events", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "eventtype", null: false, collation: "utf8_unicode_ci"
    t.text "payload"
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.integer "undone_jobs", default: 0
    t.boolean "mails_sent", default: false
    t.index ["created_at"], name: "index_events_on_created_at"
    t.index ["eventtype"], name: "index_events_on_eventtype"
    t.index ["mails_sent"], name: "index_events_on_mails_sent"
  end

  create_table "flags", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.column "status", "enum('enable','disable')", null: false, collation: "utf8_general_ci"
    t.string "repo", collation: "utf8_general_ci"
    t.integer "project_id"
    t.integer "package_id"
    t.integer "architecture_id"
    t.integer "position", null: false
    t.column "flag", "enum('useforbuild','sourceaccess','binarydownload','debuginfo','build','publish','access','lock')", null: false, collation: "utf8_general_ci"
    t.index ["architecture_id"], name: "architecture_id"
    t.index ["flag"], name: "index_flags_on_flag"
    t.index ["package_id"], name: "index_flags_on_package_id"
    t.index ["project_id"], name: "index_flags_on_project_id"
  end

  create_table "flipper_features", id: :integer, charset: "utf8", collation: "utf8_bin", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", id: :integer, charset: "utf8", collation: "utf8_bin", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "group_maintainers", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.index ["group_id"], name: "group_id"
    t.index ["user_id"], name: "user_id"
  end

  create_table "groups", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.string "title", limit: 200, default: "", null: false, collation: "utf8_general_ci"
    t.integer "parent_id"
    t.string "email", collation: "utf8_bin"
    t.index ["parent_id"], name: "groups_parent_id_index"
    t.index ["title"], name: "index_groups_on_title"
  end

  create_table "groups_notifications", id: false, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "notification_id", null: false
    t.bigint "group_id", null: false
    t.index ["group_id", "notification_id"], name: "index_groups_notifications_on_group_id_and_notification_id"
    t.index ["notification_id", "group_id"], name: "index_groups_notifications_on_notification_id_and_group_id"
  end

  create_table "groups_roles", id: false, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "group_id", default: 0, null: false
    t.integer "role_id", default: 0, null: false
    t.datetime "created_at"
    t.index ["group_id", "role_id"], name: "groups_roles_all_index", unique: true
    t.index ["role_id"], name: "role_id"
  end

  create_table "groups_users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "group_id", default: 0, null: false
    t.integer "user_id", default: 0, null: false
    t.datetime "created_at"
    t.boolean "email", default: true
    t.boolean "web", default: true
    t.index ["group_id", "user_id"], name: "groups_users_all_index", unique: true
    t.index ["user_id"], name: "user_id"
  end

  create_table "history_elements", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "type", null: false, collation: "utf8_general_ci"
    t.integer "op_object_id", null: false
    t.datetime "created_at", null: false
    t.integer "user_id", null: false
    t.string "description_extension", collation: "utf8_general_ci"
    t.text "comment"
    t.index ["created_at"], name: "index_history_elements_on_created_at"
    t.index ["op_object_id", "type"], name: "index_search"
    t.index ["type"], name: "index_history_elements_on_type"
  end

  create_table "incident_counter", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "maintenance_db_project_id"
    t.integer "counter", default: 0
  end

  create_table "incident_updateinfo_counter_values", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "updateinfo_counter_id", null: false
    t.integer "project_id", null: false
    t.integer "value", null: false
    t.datetime "released_at", null: false
    t.index ["project_id"], name: "project_id"
    t.index ["updateinfo_counter_id", "project_id"], name: "uniq_id_index"
  end

  create_table "issue_trackers", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false, collation: "utf8_general_ci"
    t.column "kind", "enum('other','bugzilla','cve','fate','trac','launchpad','sourceforge','github','jira')", null: false
    t.string "description", collation: "utf8_general_ci"
    t.string "url", null: false, collation: "utf8_general_ci"
    t.string "show_url", collation: "utf8_general_ci"
    t.string "regex", null: false, collation: "utf8_general_ci"
    t.string "user", collation: "utf8_general_ci"
    t.string "password", collation: "utf8_general_ci"
    t.text "label", null: false, collation: "utf8_general_ci"
    t.datetime "issues_updated", null: false
    t.boolean "enable_fetch", default: false
  end

  create_table "issues", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false, collation: "utf8_general_ci"
    t.integer "issue_tracker_id", null: false
    t.string "summary", collation: "utf8_general_ci"
    t.integer "owner_id"
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.column "state", "enum('OPEN','CLOSED','UNKNOWN')", collation: "utf8_general_ci"
    t.index ["issue_tracker_id"], name: "issue_tracker_id"
    t.index ["name", "issue_tracker_id"], name: "index_issues_on_name_and_issue_tracker_id"
    t.index ["owner_id"], name: "owner_id"
  end

  create_table "kiwi_descriptions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "image_id"
    t.integer "description_type", default: 0
    t.string "author", collation: "utf8_general_ci"
    t.string "contact", collation: "utf8_general_ci"
    t.string "specification", collation: "utf8_general_ci"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["image_id"], name: "index_kiwi_descriptions_on_image_id"
  end

  create_table "kiwi_images", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", collation: "utf8_general_ci"
    t.string "md5_last_revision", limit: 32, collation: "utf8_general_ci"
    t.datetime "created_at", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "use_project_repositories", default: false
  end

  create_table "kiwi_package_groups", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "kiwi_type", null: false
    t.string "profiles", collation: "utf8_general_ci"
    t.string "pattern_type", collation: "utf8_general_ci"
    t.integer "image_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["image_id"], name: "index_kiwi_package_groups_on_image_id"
  end

  create_table "kiwi_packages", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false, collation: "utf8_general_ci"
    t.string "arch", collation: "utf8_general_ci"
    t.string "replaces", collation: "utf8_general_ci"
    t.boolean "bootinclude"
    t.boolean "bootdelete"
    t.integer "package_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["package_group_id"], name: "index_kiwi_packages_on_package_group_id"
  end

  create_table "kiwi_preferences", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "image_id"
    t.integer "type_image"
    t.string "type_containerconfig_name", collation: "utf8_general_ci"
    t.string "type_containerconfig_tag", collation: "utf8_general_ci"
    t.string "version", collation: "utf8_general_ci"
    t.string "profile", limit: 191
    t.index ["image_id"], name: "index_kiwi_preferences_on_image_id"
  end

  create_table "kiwi_profiles", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", limit: 191, null: false
    t.string "description", limit: 191, null: false
    t.boolean "selected", null: false
    t.integer "image_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["image_id"], name: "index_kiwi_profiles_on_image_id"
    t.index ["name", "image_id"], name: "name_once_per_image", unique: true
  end

  create_table "kiwi_repositories", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "image_id"
    t.string "repo_type", collation: "utf8_general_ci"
    t.string "source_path", collation: "utf8_general_ci"
    t.integer "order"
    t.integer "priority"
    t.datetime "created_at", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "alias", collation: "utf8_general_ci"
    t.boolean "imageinclude"
    t.string "password", collation: "utf8_general_ci"
    t.boolean "prefer_license"
    t.boolean "replaceable"
    t.string "username", collation: "utf8_general_ci"
    t.index ["image_id", "order"], name: "index_kiwi_repositories_on_image_id_and_order", unique: true
    t.index ["image_id"], name: "index_kiwi_repositories_on_image_id"
  end

  create_table "linked_projects", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "db_project_id", null: false
    t.integer "linked_db_project_id"
    t.integer "position"
    t.string "linked_remote_project_name", collation: "utf8_general_ci"
    t.column "vrevmode", "enum('standard','unextend','extend')", default: "standard", collation: "utf8_bin"
    t.index ["db_project_id", "linked_db_project_id"], name: "linked_projects_index", unique: true
  end

  create_table "maintained_projects", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "maintenance_project_id", null: false
    t.index ["maintenance_project_id"], name: "maintenance_project_id"
    t.index ["project_id", "maintenance_project_id"], name: "uniq_index", unique: true
  end

  create_table "maintenance_incidents", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "db_project_id"
    t.integer "maintenance_db_project_id"
    t.string "updateinfo_id", collation: "utf8_general_ci"
    t.integer "incident_id"
    t.datetime "released_at"
    t.index ["db_project_id"], name: "index_maintenance_incidents_on_db_project_id"
    t.index ["maintenance_db_project_id"], name: "index_maintenance_incidents_on_maintenance_db_project_id"
  end

  create_table "notifications", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "event_type", null: false, collation: "utf8_general_ci"
    t.text "event_payload", null: false
    t.string "subscription_receiver_role", null: false, collation: "utf8_general_ci"
    t.boolean "delivered", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "subscriber_type", collation: "utf8_general_ci"
    t.integer "subscriber_id"
    t.string "notifiable_type"
    t.integer "notifiable_id"
    t.string "bs_request_oldstate", collation: "utf8_unicode_ci"
    t.string "bs_request_state"
    t.string "title", collation: "utf8_unicode_ci"
    t.boolean "rss", default: false
    t.boolean "web", default: false
    t.datetime "last_seen_at"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["subscriber_type", "subscriber_id"], name: "index_notifications_on_subscriber_type_and_subscriber_id"
  end

  create_table "notified_projects", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "notification_id", null: false
    t.integer "project_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.index ["notification_id", "project_id"], name: "index_notified_projects_on_notification_id_and_project_id", unique: true
    t.index ["notification_id"], name: "index_notified_projects_on_notification_id"
  end

  create_table "package_issues", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "package_id", null: false
    t.integer "issue_id", null: false
    t.column "change", "enum('added','deleted','changed','kept')", collation: "utf8_general_ci"
    t.index ["issue_id"], name: "index_package_issues_on_issue_id"
    t.index ["package_id", "issue_id"], name: "index_package_issues_on_package_id_and_issue_id"
  end

  create_table "package_kinds", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "package_id"
    t.column "kind", "enum('patchinfo','aggregate','link','channel','product')", null: false, collation: "utf8_general_ci"
    t.index ["package_id"], name: "index_package_kinds_on_package_id"
  end

  create_table "packages", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "name", limit: 200, null: false, collation: "utf8_bin"
    t.string "title", collation: "utf8_general_ci"
    t.text "description"
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.string "url", collation: "utf8_general_ci"
    t.float "activity_index", default: 100.0
    t.string "bcntsynctag", collation: "utf8_general_ci"
    t.integer "develpackage_id"
    t.boolean "delta", default: true, null: false
    t.string "releasename", collation: "utf8_bin"
    t.integer "kiwi_image_id"
    t.string "scmsync"
    t.index ["develpackage_id"], name: "devel_package_id_index"
    t.index ["kiwi_image_id"], name: "index_packages_on_kiwi_image_id"
    t.index ["project_id", "name"], name: "packages_all_index", unique: true
    t.index ["updated_at"], name: "updated_at_index"
  end

  create_table "path_elements", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "parent_id", null: false
    t.integer "repository_id", null: false
    t.integer "position", null: false
    t.column "kind", "enum('standard','hostsystem')", default: "standard"
    t.index ["parent_id", "repository_id", "kind"], name: "parent_repository_index", unique: true
    t.index ["repository_id"], name: "repository_id"
  end

  create_table "product_channels", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "channel_id", null: false
    t.index ["channel_id", "product_id"], name: "index_product_channels_on_channel_id_and_product_id", unique: true
    t.index ["product_id"], name: "product_id"
  end

  create_table "product_media", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "product_id"
    t.integer "repository_id"
    t.integer "arch_filter_id"
    t.string "name", collation: "utf8_general_ci"
    t.index ["arch_filter_id"], name: "index_product_media_on_arch_filter_id"
    t.index ["name"], name: "index_product_media_on_name"
    t.index ["product_id", "repository_id", "name", "arch_filter_id"], name: "index_unique", unique: true
    t.index ["product_id"], name: "index_product_media_on_product_id"
    t.index ["repository_id"], name: "repository_id"
  end

  create_table "product_update_repositories", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "product_id"
    t.integer "repository_id"
    t.integer "arch_filter_id"
    t.index ["arch_filter_id"], name: "index_product_update_repositories_on_arch_filter_id"
    t.index ["product_id", "repository_id", "arch_filter_id"], name: "index_unique", unique: true
    t.index ["product_id"], name: "index_product_update_repositories_on_product_id"
    t.index ["repository_id"], name: "repository_id"
  end

  create_table "products", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", null: false, collation: "utf8_unicode_ci"
    t.integer "package_id", null: false
    t.string "cpe", collation: "utf8_unicode_ci"
    t.string "version", collation: "utf8_unicode_ci"
    t.string "baseversion", collation: "utf8_unicode_ci"
    t.string "patchlevel", collation: "utf8_unicode_ci"
    t.string "release", collation: "utf8_unicode_ci"
    t.index ["name", "package_id"], name: "index_products_on_name_and_package_id", unique: true
    t.index ["package_id"], name: "package_id"
  end

  create_table "project_log_entries", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "project_id"
    t.string "user_name", collation: "utf8_unicode_ci"
    t.string "package_name", collation: "utf8_unicode_ci"
    t.integer "bs_request_id"
    t.datetime "datetime"
    t.string "event_type", collation: "utf8_unicode_ci"
    t.text "additional_info"
    t.index ["bs_request_id"], name: "index_project_log_entries_on_bs_request_id"
    t.index ["datetime"], name: "index_project_log_entries_on_datetime"
    t.index ["event_type"], name: "index_project_log_entries_on_event_type"
    t.index ["package_name"], name: "index_project_log_entries_on_package_name"
    t.index ["project_id", "event_type"], name: "index_project_log_entries_on_project_id_and_event_type"
    t.index ["project_id"], name: "project_id"
    t.index ["user_name"], name: "index_project_log_entries_on_user_name"
  end

  create_table "projects", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "name", limit: 200, null: false, collation: "utf8_bin"
    t.string "title", collation: "utf8_general_ci"
    t.text "description"
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.string "remoteurl", collation: "utf8_general_ci"
    t.string "remoteproject", collation: "utf8_general_ci"
    t.integer "develproject_id"
    t.boolean "delta", default: true, null: false
    t.column "kind", "enum('standard','maintenance','maintenance_incident','maintenance_release')", default: "standard", collation: "utf8_bin"
    t.string "url", collation: "utf8_bin"
    t.string "required_checks"
    t.integer "staging_workflow_id"
    t.string "scmsync"
    t.index ["develproject_id"], name: "devel_project_id_index"
    t.index ["name"], name: "projects_name_index", unique: true
    t.index ["staging_workflow_id"], name: "index_projects_on_staging_workflow_id"
    t.index ["updated_at"], name: "updated_at_index"
  end

  create_table "relationships", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "package_id"
    t.integer "project_id"
    t.integer "role_id", null: false
    t.integer "user_id"
    t.integer "group_id"
    t.index ["group_id"], name: "group_id"
    t.index ["package_id", "role_id", "group_id"], name: "index_relationships_on_package_id_and_role_id_and_group_id", unique: true
    t.index ["package_id", "role_id", "user_id"], name: "index_relationships_on_package_id_and_role_id_and_user_id", unique: true
    t.index ["project_id", "role_id", "group_id"], name: "index_relationships_on_project_id_and_role_id_and_group_id", unique: true
    t.index ["project_id", "role_id", "user_id"], name: "index_relationships_on_project_id_and_role_id_and_user_id", unique: true
    t.index ["role_id"], name: "role_id"
    t.index ["user_id"], name: "user_id"
  end

  create_table "release_targets", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.integer "target_repository_id", null: false
    t.column "trigger", "enum('manual','allsucceeded','maintenance','obsgendiff')"
    t.index ["repository_id"], name: "repository_id_index"
    t.index ["target_repository_id"], name: "index_release_targets_on_target_repository_id"
  end

  create_table "repositories", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "db_project_id", null: false
    t.string "name", null: false, collation: "utf8_bin"
    t.string "remote_project_name", default: "", null: false, collation: "utf8_bin"
    t.column "rebuild", "enum('transitive','direct','local')", collation: "utf8_general_ci"
    t.column "block", "enum('all','local','never')", collation: "utf8_general_ci"
    t.column "linkedbuild", "enum('off','localdep','all','alldirect')"
    t.integer "hostsystem_id"
    t.string "required_checks"
    t.index ["db_project_id", "name", "remote_project_name"], name: "projects_name_index", unique: true
    t.index ["hostsystem_id"], name: "hostsystem_id"
    t.index ["remote_project_name"], name: "remote_project_name_index"
  end

  create_table "repository_architectures", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.integer "architecture_id", null: false
    t.integer "position", default: 0, null: false
    t.string "required_checks"
    t.index ["architecture_id"], name: "architecture_id"
    t.index ["repository_id", "architecture_id"], name: "arch_repo_index", unique: true
  end

  create_table "reviews", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "bs_request_id"
    t.string "creator", collation: "utf8_unicode_ci"
    t.string "reviewer", collation: "utf8_unicode_ci"
    t.text "reason"
    t.string "state", collation: "utf8_unicode_ci"
    t.string "by_user", collation: "utf8_general_ci"
    t.string "by_group", collation: "utf8_general_ci"
    t.string "by_project", collation: "utf8_general_ci"
    t.string "by_package", collation: "utf8_general_ci"
    t.datetime "created_at", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "review_id"
    t.integer "user_id"
    t.integer "group_id"
    t.integer "project_id"
    t.integer "package_id"
    t.index ["bs_request_id"], name: "bs_request_id"
    t.index ["by_group"], name: "index_reviews_on_by_group"
    t.index ["by_package", "by_project"], name: "index_reviews_on_by_package_and_by_project"
    t.index ["by_project"], name: "index_reviews_on_by_project"
    t.index ["by_user"], name: "index_reviews_on_by_user"
    t.index ["creator"], name: "index_reviews_on_creator"
    t.index ["group_id"], name: "index_reviews_on_group_id"
    t.index ["package_id"], name: "index_reviews_on_package_id"
    t.index ["project_id"], name: "index_reviews_on_project_id"
    t.index ["review_id"], name: "index_reviews_on_review_id"
    t.index ["reviewer"], name: "index_reviews_on_reviewer"
    t.index ["state", "by_group"], name: "index_reviews_on_state_and_by_group"
    t.index ["state", "by_project"], name: "index_reviews_on_state_and_by_project"
    t.index ["state", "by_user"], name: "index_reviews_on_state_and_by_user"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "roles", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "title", limit: 100, default: "", null: false, collation: "utf8_general_ci"
    t.integer "parent_id"
    t.boolean "global", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["parent_id"], name: "roles_parent_id_index"
  end

  create_table "roles_static_permissions", id: false, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "role_id", default: 0, null: false
    t.integer "static_permission_id", default: 0, null: false
    t.index ["role_id"], name: "role_id"
    t.index ["static_permission_id", "role_id"], name: "roles_static_permissions_all_index", unique: true
  end

  create_table "roles_users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "role_id", default: 0, null: false
    t.datetime "created_at"
    t.index ["role_id"], name: "role_id"
    t.index ["user_id", "role_id"], name: "roles_users_all_index", unique: true
  end

  create_table "sessions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "session_id", null: false, collation: "utf8_unicode_ci"
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.index ["session_id"], name: "index_sessions_on_session_id"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "staging_request_exclusions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "staging_workflow_id", null: false
    t.integer "bs_request_id", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "number"
    t.index ["bs_request_id"], name: "index_staging_request_exclusions_on_bs_request_id"
    t.index ["staging_workflow_id"], name: "index_staging_request_exclusions_on_staging_workflow_id"
  end

  create_table "staging_workflows", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "project_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "managers_group_id"
    t.index ["managers_group_id"], name: "index_staging_workflows_on_managers_group_id"
    t.index ["project_id"], name: "index_staging_workflows_on_project_id", unique: true
  end

  create_table "static_permissions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "title", limit: 200, default: "", null: false, collation: "utf8_general_ci"
    t.index ["title"], name: "static_permissions_title_index", unique: true
  end

  create_table "status_checks", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "state"
    t.string "url"
    t.string "short_description"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status_reports_id"
    t.index ["status_reports_id"], name: "index_status_checks_on_status_reports_id"
  end

  create_table "status_histories", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "time"
    t.string "key", collation: "utf8_general_ci"
    t.float "value", null: false
    t.index ["key"], name: "index_status_histories_on_key"
    t.index ["time", "key"], name: "index_status_histories_on_time_and_key"
  end

  create_table "status_message_acknowledgements", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "status_message_id"
    t.integer "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["status_message_id"], name: "index_status_message_acknowledgements_on_status_message_id"
    t.index ["user_id"], name: "index_status_message_acknowledgements_on_user_id"
  end

  create_table "status_messages", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.datetime "created_at"
    t.text "message"
    t.integer "user_id"
    t.integer "severity"
    t.integer "communication_scope", default: 0
    t.index ["created_at"], name: "index_status_messages_on_created_at"
    t.index ["user_id"], name: "user"
  end

  create_table "status_reports", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "uuid"
    t.string "checkable_type", limit: 191
    t.integer "checkable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checkable_type", "checkable_id"], name: "index_status_reports_on_checkable_type_and_checkable_id"
  end

  create_table "tokens", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.string "string", collation: "utf8_unicode_ci"
    t.integer "user_id", null: false
    t.integer "package_id"
    t.string "type", collation: "utf8_unicode_ci"
    t.string "scm_token"
    t.string "name", limit: 64, default: ""
    t.datetime "triggered_at"
    t.index ["package_id"], name: "package_id"
    t.index ["scm_token"], name: "index_tokens_on_scm_token"
    t.index ["string"], name: "index_tokens_on_string", unique: true
    t.index ["user_id"], name: "user_id"
  end

  create_table "updateinfo_counters", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "maintenance_db_project_id"
    t.integer "day"
    t.integer "month"
    t.integer "year"
    t.integer "counter", default: 0
  end

  create_table "user_registrations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.text "token", null: false, collation: "utf8_general_ci"
    t.datetime "created_at"
    t.datetime "expires_at"
    t.index ["expires_at"], name: "user_registrations_expires_at_index"
    t.index ["user_id"], name: "user_registrations_user_id_index", unique: true
  end

  create_table "users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at", precision: 6
    t.datetime "last_logged_in_at"
    t.integer "login_failure_count", default: 0, null: false
    t.text "login", collation: "utf8_bin"
    t.string "email", limit: 200, default: "", null: false, collation: "utf8_general_ci"
    t.string "realname", limit: 200, default: "", null: false, collation: "utf8_general_ci"
    t.string "password_digest", collation: "utf8_bin"
    t.string "deprecated_password", collation: "utf8_bin"
    t.string "deprecated_password_hash_type", collation: "utf8_bin"
    t.string "deprecated_password_salt", collation: "utf8_bin"
    t.text "adminnote"
    t.column "state", "enum('unconfirmed','confirmed','locked','deleted','subaccount')", default: "unconfirmed", collation: "utf8_bin"
    t.integer "owner_id"
    t.boolean "ignore_auth_services", default: false
    t.boolean "in_beta", default: false
    t.boolean "in_rollout", default: true
    t.string "biography", default: ""
    t.index ["deprecated_password"], name: "users_password_index"
    t.index ["in_beta"], name: "index_users_on_in_beta"
    t.index ["in_rollout"], name: "index_users_on_in_rollout"
    t.index ["login"], name: "users_login_index", unique: true, length: 255
  end

  create_table "watched_projects", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC", force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "project_id", null: false
    t.index ["user_id"], name: "watched_projects_users_fk_1"
  end

  create_table "workflow_artifacts_per_steps", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "workflow_run_id", null: false
    t.string "step"
    t.text "artifacts"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["workflow_run_id"], name: "index_workflow_artifacts_per_steps_on_workflow_run_id"
  end

  create_table "workflow_runs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.text "request_headers", null: false
    t.text "request_payload", null: false
    t.integer "status", limit: 1, default: 0, null: false
    t.text "response_body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "token_id", null: false
    t.string "response_url"
    t.index ["token_id"], name: "index_workflow_runs_on_token_id"
  end

  add_foreign_key "attrib_allowed_values", "attrib_types", name: "attrib_allowed_values_ibfk_1"
  add_foreign_key "attrib_default_values", "attrib_types", name: "attrib_default_values_ibfk_1"
  add_foreign_key "attrib_issues", "attribs", name: "attrib_issues_ibfk_1"
  add_foreign_key "attrib_issues", "issues", name: "attrib_issues_ibfk_2"
  add_foreign_key "attrib_namespace_modifiable_bies", "attrib_namespaces", name: "attrib_namespace_modifiable_bies_ibfk_1"
  add_foreign_key "attrib_namespace_modifiable_bies", "groups", name: "attrib_namespace_modifiable_bies_ibfk_5"
  add_foreign_key "attrib_namespace_modifiable_bies", "users", name: "attrib_namespace_modifiable_bies_ibfk_4"
  add_foreign_key "attrib_type_modifiable_bies", "groups", name: "attrib_type_modifiable_bies_ibfk_2"
  add_foreign_key "attrib_type_modifiable_bies", "roles", name: "attrib_type_modifiable_bies_ibfk_3"
  add_foreign_key "attrib_type_modifiable_bies", "users", name: "attrib_type_modifiable_bies_ibfk_1"
  add_foreign_key "attrib_types", "attrib_namespaces", name: "attrib_types_ibfk_1"
  add_foreign_key "attrib_values", "attribs", name: "attrib_values_ibfk_1"
  add_foreign_key "attribs", "attrib_types", name: "attribs_ibfk_1"
  add_foreign_key "attribs", "packages", name: "attribs_ibfk_2"
  add_foreign_key "attribs", "projects", name: "attribs_ibfk_3"
  add_foreign_key "backend_packages", "packages", column: "links_to_id", name: "backend_packages_ibfk_2"
  add_foreign_key "backend_packages", "packages", name: "backend_packages_ibfk_1"
  add_foreign_key "binary_releases", "packages", column: "release_package_id", name: "binary_releases_ibfk_2"
  add_foreign_key "binary_releases", "repositories", name: "binary_releases_ibfk_1"
  add_foreign_key "bs_request_action_accept_infos", "bs_request_actions", name: "bs_request_action_accept_infos_ibfk_1"
  add_foreign_key "bs_request_actions", "bs_requests", name: "bs_request_actions_ibfk_1"
  add_foreign_key "channel_binaries", "architectures", name: "channel_binaries_ibfk_4"
  add_foreign_key "channel_binaries", "channel_binary_lists", name: "channel_binaries_ibfk_1"
  add_foreign_key "channel_binaries", "projects", name: "channel_binaries_ibfk_2"
  add_foreign_key "channel_binaries", "repositories", name: "channel_binaries_ibfk_3"
  add_foreign_key "channel_binary_lists", "architectures", name: "channel_binary_lists_ibfk_4"
  add_foreign_key "channel_binary_lists", "channels", name: "channel_binary_lists_ibfk_1"
  add_foreign_key "channel_binary_lists", "projects", name: "channel_binary_lists_ibfk_2"
  add_foreign_key "channel_binary_lists", "repositories", name: "channel_binary_lists_ibfk_3"
  add_foreign_key "channel_targets", "channels", name: "channel_targets_ibfk_1"
  add_foreign_key "channel_targets", "repositories", name: "channel_targets_ibfk_2"
  add_foreign_key "channels", "packages", name: "channels_ibfk_1"
  add_foreign_key "comments", "comments", column: "parent_id", name: "comments_ibfk_4"
  add_foreign_key "comments", "users", name: "comments_ibfk_1"
  add_foreign_key "download_repositories", "repositories", name: "download_repositories_ibfk_1"
  add_foreign_key "flags", "architectures", name: "flags_ibfk_3"
  add_foreign_key "flags", "packages", name: "flags_ibfk_5"
  add_foreign_key "flags", "projects", name: "flags_ibfk_4"
  add_foreign_key "group_maintainers", "groups", name: "group_maintainers_ibfk_1"
  add_foreign_key "group_maintainers", "users", name: "group_maintainers_ibfk_2"
  add_foreign_key "groups_roles", "groups", name: "groups_roles_ibfk_1"
  add_foreign_key "groups_roles", "roles", name: "groups_roles_ibfk_2"
  add_foreign_key "groups_users", "groups", name: "groups_users_ibfk_1"
  add_foreign_key "groups_users", "users", name: "groups_users_ibfk_2"
  add_foreign_key "incident_updateinfo_counter_values", "projects", name: "incident_updateinfo_counter_values_ibfk_1"
  add_foreign_key "issues", "issue_trackers", name: "issues_ibfk_2"
  add_foreign_key "issues", "users", column: "owner_id", name: "issues_ibfk_1"
  add_foreign_key "kiwi_package_groups", "kiwi_images", column: "image_id"
  add_foreign_key "kiwi_packages", "kiwi_package_groups", column: "package_group_id"
  add_foreign_key "maintained_projects", "projects", column: "maintenance_project_id", name: "maintained_projects_ibfk_2"
  add_foreign_key "maintained_projects", "projects", name: "maintained_projects_ibfk_1"
  add_foreign_key "package_issues", "issues", name: "package_issues_ibfk_2"
  add_foreign_key "package_issues", "packages", name: "package_issues_ibfk_1"
  add_foreign_key "package_kinds", "packages", name: "package_kinds_ibfk_1"
  add_foreign_key "packages", "kiwi_images"
  add_foreign_key "packages", "packages", column: "develpackage_id", name: "packages_ibfk_3"
  add_foreign_key "packages", "projects", name: "packages_ibfk_4"
  add_foreign_key "path_elements", "repositories", column: "parent_id", name: "path_elements_ibfk_1"
  add_foreign_key "path_elements", "repositories", name: "path_elements_ibfk_2"
  add_foreign_key "product_channels", "channels", name: "product_channels_ibfk_1"
  add_foreign_key "product_channels", "products", name: "product_channels_ibfk_2"
  add_foreign_key "product_media", "architectures", column: "arch_filter_id", name: "product_media_ibfk_3"
  add_foreign_key "product_media", "products", name: "product_media_ibfk_1"
  add_foreign_key "product_media", "repositories", name: "product_media_ibfk_2"
  add_foreign_key "product_update_repositories", "architectures", column: "arch_filter_id", name: "product_update_repositories_ibfk_3"
  add_foreign_key "product_update_repositories", "products", name: "product_update_repositories_ibfk_1"
  add_foreign_key "product_update_repositories", "repositories", name: "product_update_repositories_ibfk_2"
  add_foreign_key "products", "packages", name: "products_ibfk_1"
  add_foreign_key "project_log_entries", "projects", name: "project_log_entries_ibfk_1"
  add_foreign_key "relationships", "groups", name: "relationships_ibfk_3"
  add_foreign_key "relationships", "packages", name: "relationships_ibfk_5"
  add_foreign_key "relationships", "projects", name: "relationships_ibfk_4"
  add_foreign_key "relationships", "roles", name: "relationships_ibfk_1"
  add_foreign_key "relationships", "users", name: "relationships_ibfk_2"
  add_foreign_key "release_targets", "repositories", column: "target_repository_id", name: "release_targets_ibfk_2"
  add_foreign_key "release_targets", "repositories", name: "release_targets_ibfk_1"
  add_foreign_key "repositories", "projects", column: "db_project_id", name: "repositories_ibfk_1"
  add_foreign_key "repositories", "repositories", column: "hostsystem_id", name: "repositories_ibfk_2"
  add_foreign_key "repository_architectures", "architectures", name: "repository_architectures_ibfk_2"
  add_foreign_key "repository_architectures", "repositories", name: "repository_architectures_ibfk_1"
  add_foreign_key "reviews", "bs_requests", name: "reviews_ibfk_1"
  add_foreign_key "reviews", "reviews"
  add_foreign_key "roles", "roles", column: "parent_id", name: "roles_ibfk_1"
  add_foreign_key "roles_static_permissions", "roles", name: "roles_static_permissions_ibfk_1"
  add_foreign_key "roles_static_permissions", "static_permissions", name: "roles_static_permissions_ibfk_2"
  add_foreign_key "roles_users", "roles", name: "roles_users_ibfk_2"
  add_foreign_key "roles_users", "users", name: "roles_users_ibfk_1"
  add_foreign_key "status_checks", "status_reports", column: "status_reports_id"
  add_foreign_key "tokens", "packages", name: "tokens_ibfk_2"
  add_foreign_key "tokens", "users", name: "tokens_ibfk_1"
  add_foreign_key "user_registrations", "users", name: "user_registrations_ibfk_1"
  add_foreign_key "watched_projects", "users", name: "watched_projects_ibfk_1"
end
