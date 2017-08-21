class RemoveProjectsTags < ActiveRecord::Migration[5.1]
  def change
    reversible do |dir|
      dir.down do
        add_foreign_key "db_projects_tags", "projects", column: "db_project_id", name: "db_projects_tags_ibfk_1"
        add_foreign_key "db_projects_tags", "tags", name: "db_projects_tags_ibfk_2"
      end
    end
    drop_table "db_projects_tags", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.integer "db_project_id", null: false
      t.integer "tag_id",        null: false
      t.index ["db_project_id", "tag_id"], name: "projects_tags_all_index", unique: true, using: :btree
      t.index ["tag_id"], name: "tag_id", using: :btree
    end
  end
end
