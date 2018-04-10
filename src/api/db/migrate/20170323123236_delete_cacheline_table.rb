# frozen_string_literal: true

class DeleteCachelineTable < ActiveRecord::Migration[5.1]
  def change
    remove_index :cache_lines, [:project, :package]

    drop_table :cache_lines do |t|
      t.string :key, limit: 4096, null: false
      t.string :package, limit: 255
      t.string :project, limit: 255
      t.integer :request
      t.datetime :created_at
    end
  end
end
