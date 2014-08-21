class AddIndexForBinaryTracking < ActiveRecord::Migration
  def self.up
    add_index :binary_releases, :medium
    add_index :product_media, :name
  end

  def self.down
    remove_index :binary_releases, :medium
    remove_index :product_media, :name
  end
end
