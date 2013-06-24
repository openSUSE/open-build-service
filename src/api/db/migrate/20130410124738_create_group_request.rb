class CreateGroupRequest < ActiveRecord::Migration
  def change
    create_table :group_request_requests, id: false do |t|
      t.integer :bs_request_action_group_id 
      t.integer :bs_request_id
    end
  end
end
