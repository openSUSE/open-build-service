class IndexForCacheLines < ActiveRecord::Migration
  def change
    add_index :cache_lines, :project
    add_index :cache_lines, [:project, :package]
  end
end
