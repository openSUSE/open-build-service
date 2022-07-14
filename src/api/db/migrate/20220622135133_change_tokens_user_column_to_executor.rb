class ChangeTokensUserColumnToExecutor < ActiveRecord::Migration[6.1]
  def change
    safety_assured { rename_column :tokens, :user_id, :executor_id }
  end
end
