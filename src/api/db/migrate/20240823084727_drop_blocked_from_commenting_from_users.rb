class DropBlockedFromCommentingFromUsers < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :users, :blocked_from_commenting, :boolean }
  end
end
