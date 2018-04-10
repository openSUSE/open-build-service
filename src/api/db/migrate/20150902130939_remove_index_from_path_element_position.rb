# frozen_string_literal: true

class RemoveIndexFromPathElementPosition < ActiveRecord::Migration[4.2]
  def self.up
    remove_index :path_elements, name: :parent_repo_pos_index
  end

  def self.down
    add_index :path_elements, [:parent_id, :position], unique: true, name: :parent_repo_pos_index
  end
end
