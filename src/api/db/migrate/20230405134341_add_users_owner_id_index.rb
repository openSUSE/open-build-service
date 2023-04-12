class AddUsersOwnerIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :users, %w[owner_id], name: :index_users_owner_id
  end
end
