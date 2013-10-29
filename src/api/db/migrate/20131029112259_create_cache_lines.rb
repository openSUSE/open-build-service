class CreateCacheLines < ActiveRecord::Migration
  def change
    create_table :cache_lines do |t|
      t.string :key, null: false
      t.string :package
      t.string :project
      t.integer :request
      t.datetime :created_at
    end
  end
end
