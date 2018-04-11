# frozen_string_literal: true

class RemoveBlacklistTags < ActiveRecord::Migration[5.1]
  def change
    drop_table 'blacklist_tags', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string   'name', collation: 'utf8_general_ci'
      t.datetime 'created_at'
    end
  end
end
