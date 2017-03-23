class DeleteCachelineTable < ActiveRecord::Migration[5.0]
  def up
    drop_table :cache_lines if table_exists?(:cache_lines)
  end

  def down
    create_table :cache_lines do |t|
      t.string :key, limit: 4096, null: false
      t.string :package, limit: 255
      t.string :project, limit: 255
      t.integer :request
      t.datetime :created_at
    end

    add_index :cache_lines, [:project, :package]
  end
end
