# frozen_string_literal: true

class AddIndexBsRequestsAction < ActiveRecord::Migration[5.1]
  def change
    add_index :bs_request_actions, :target_project_id
    add_index :bs_request_actions, :target_package_id
  end
end
