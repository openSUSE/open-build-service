class RemoveTaggings < ActiveRecord::Migration[5.1]
  def change
    reversible do |dir|
      dir.down do
        add_foreign_key "taggings", "tags", name: "taggings_ibfk_1"
        add_foreign_key "taggings", "users", name: "taggings_ibfk_2"
      end
    end
    drop_table "taggings", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin" do |t|
      t.integer "taggable_id"
      t.string  "taggable_type", collation: "utf8_general_ci"
      t.integer "tag_id"
      t.integer "user_id"
      t.index ["taggable_id", "taggable_type", "tag_id", "user_id"], name: "taggings_taggable_id_index", unique: true, using: :btree
      t.index ["taggable_type"], name: "index_taggings_on_taggable_type", using: :btree
      t.index ["tag_id"], name: "tag_id", using: :btree
      t.index ["user_id"], name: "user_id", using: :btree
    end
  end
end
