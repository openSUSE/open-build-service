class AddBsRequestActionsSeenByUsersUserIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :bs_request_actions_seen_by_users, %w[user_id], name: :index_bs_request_actions_seen_by_users_user_id
  end
end
