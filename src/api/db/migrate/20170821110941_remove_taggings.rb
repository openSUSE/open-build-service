# frozen_string_literal: true
class RemoveTaggings < ActiveRecord::Migration[5.1]
  def change
    drop_table 'taggings', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'taggable_id'
      t.string  'taggable_type', collation: 'utf8_general_ci'
      t.references :tag, index: { unique: true }, foreign_key: true
      t.references :user, index: { unique: true }, type: :integer, foreign_key: true
      t.index ['taggable_id', 'taggable_type'], name: 'taggings_taggable_id_index', unique: true, using: :btree
    end
  end
end
