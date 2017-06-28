class DropProjectLogEntry < ActiveRecord::Migration[5.1]
  def change
    drop_table "project_log_entries", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci" do |t|
      t.integer  "project_id"
      t.string   "user_name"
      t.string   "package_name"
      t.integer  "bs_request_id"
      t.datetime "datetime"
      t.string   "event_type"
      t.text     "additional_info", limit: 65535
      t.index ["project_id"], name: "project_id", using: :btree
      t.index ["user_name"], name: "index_project_log_entries_on_user_name", using: :btree
      t.index ["package_name"], name: "index_project_log_entries_on_package_name", using: :btree
      t.index ["bs_request_id"], name: "index_project_log_entries_on_bs_request_id", using: :btree
      t.index ["event_type"], name: "index_project_log_entries_on_event_type", using: :btree
      t.index ["datetime"], name: "index_project_log_entries_on_datetime", using: :btree
    end
  end
end
