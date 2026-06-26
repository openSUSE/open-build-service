class AddBlockedFromCommentingIndexToUsers < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :blocked_from_commenting
  end
end
