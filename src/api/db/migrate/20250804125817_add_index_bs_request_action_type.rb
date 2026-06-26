class AddIndexBsRequestActionType < ActiveRecord::Migration[7.2]
  def change
    add_index :bs_request_actions, :type
  end
end
