class CreateBsRequestActionsSeenByUsers < ActiveRecord::Migration[7.0]
  def change
    create_join_table :bs_request_actions, :users, table_name: :bs_request_actions_seen_by_users do |t|
      t.index [:bs_request_action_id, :user_id], name: :bs_request_actions_seen_by_users_index
    end
  end
end
