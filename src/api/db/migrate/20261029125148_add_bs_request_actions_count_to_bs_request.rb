class AddBsRequestActionsCountToBsRequest < ActiveRecord::Migration[8.1]
  def change
    add_column :bs_requests, :bs_request_actions_count, :integer, default: 0, null: false
    add_index :bs_requests, :bs_request_actions_count
  end
end
