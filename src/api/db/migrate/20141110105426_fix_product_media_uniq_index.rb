class FixProductMediaUniqIndex < ActiveRecord::Migration
  def self.up
    remove_index :product_media, unique: true, :name => "index_unique"
    remove_index :product_update_repositories, unique: true, :name => "index_unique"

    add_index :product_media, [:product_id, :repository_id, :name, :arch_filter_id], unique: true, :name => "index_unique"
    add_index :product_update_repositories, [:product_id, :repository_id, :arch_filter_id], unique: true, :name => "index_unique"
  end

  def self.down
    remove_index :product_media, unique: true, :name => "index_unique"
    remove_index :product_update_repositories, unique: true, :name => "index_unique"

    add_index :product_media, [:product_id, :repository_id, :name], unique: true, :name => "index_unique"
    add_index :product_update_repositories, [:product_id, :repository_id], unique: true, :name => "index_unique"
  end
end
