class CreateGroupIndex < ActiveRecord::Migration
  def change
    add_index :group_request_requests, :bs_request_id
    add_index :group_request_requests, :bs_request_action_group_id
  end
end
