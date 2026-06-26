class AddBlockedFromCommentingToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :blocked_from_commenting, :boolean, default: false, null: false
  end
end
