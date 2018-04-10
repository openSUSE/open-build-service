# frozen_string_literal: true
class AddIndexForBinaryTracking < ActiveRecord::Migration[4.2]
  def self.up
    add_index :binary_releases, :medium
    add_index :product_media, :name
  end

  def self.down
    remove_index :binary_releases, :medium
    remove_index :product_media, :name
  end
end
