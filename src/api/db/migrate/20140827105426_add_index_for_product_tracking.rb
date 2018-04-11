# frozen_string_literal: true

class AddIndexForProductTracking < ActiveRecord::Migration[4.2]
  def self.up
    add_index :product_media, [:product_id, :repository_id, :name], unique: true, name: 'index_unique'
    add_index :product_update_repositories, [:product_id, :repository_id], unique: true, name: 'index_unique'
  end

  def self.down
    remove_index :product_media, name: 'index_unique'
    remove_index :product_update_repositories, name: 'index_unique'
  end
end
