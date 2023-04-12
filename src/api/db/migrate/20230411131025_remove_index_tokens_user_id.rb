class RemoveIndexTokensUserId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'tokens', 'executor_id', name: 'user_id'
  end
end
