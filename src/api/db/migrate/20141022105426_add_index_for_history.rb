# frozen_string_literal: true
class AddIndexForHistory < ActiveRecord::Migration[4.2]
  def self.up
    add_index :history_elements, [:op_object_id, :type], name: 'index_search'
    add_index :bs_requests, :superseded_by
  end

  def self.down
    remove_index :history_elements, name: 'index_search'
    remove_index :bs_requests, :superseded_by
  end
end
