# frozen_string_literal: true

class RemoveTags < ActiveRecord::Migration[5.1]
  def change
    drop_table 'tags', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string   'name', null: false, collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.index ['name'], name: 'tags_name_unique_index', unique: true, using: :btree
    end
  end
end
