# frozen_string_literal: true
class AddAndRemoveSomeIndexInBsRequestActions < ActiveRecord::Migration[5.0]
  def change
    remove_index :bs_request_actions, :target_project_id
    remove_index :bs_request_actions, :target_package_id
    add_index :bs_request_actions, [:bs_request_id, :target_project_id]
    add_index :bs_request_actions, [:bs_request_id, :target_package_id]
  end
end
